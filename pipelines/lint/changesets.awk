# Reads one Liquibase formatted SQL file and prints one finding per line as <rule>|<line>|<detail>[|<detail>]:
#   missing-rollback|<line>|<changeset id>
#   concurrent-in-transaction|<line>|<changeset id>     CONCURRENTLY used without runInTransaction:false
#   fk|<line>|<table>|<column>                         foreign key column; lint-schema.sh checks it has an index
#   drop-table|<line>|<table>
#   drop-column|<line>|<table>
#   change-column-type|<line>|<table>
#   set-not-null|<line>|<table>
#   validating-constraint|<line>|<table>                FOREIGN KEY or CHECK added without NOT VALID
#   unique-constraint-without-index|<line>|<table>      UNIQUE or PRIMARY KEY added without USING INDEX
#   blocking-index|<line>|<table>                       CREATE INDEX without CONCURRENTLY
# Changesets with splitStatements:false (plpgsql bodies) are not checked for risky statements.
# Portable awk (gawk and mawk), so it runs the same locally and on GitHub runners.

function end_statement() {
    if (stmt != "" && !no_split) check_statement(stmt, stmt_line)
    stmt = ""
}

function end_changeset() {
    end_statement()
    if (cs_line && !has_rollback) print "missing-rollback|" cs_line "|" cs_id
    if (cs_line && concurrent && !no_txn) print "concurrent-in-transaction|" cs_line "|" cs_id
}

# Last word of s, without quotes or schema prefix: 'create table if not exists public.orders' -> 'orders'
function last_word(s) {
    sub(/.*[ \t]/, "", s)
    gsub(/"/, "", s)
    sub(/.*\./, "", s)
    return s
}

# Table name at the end of the first match of re in s, or "".
function table_after(s, re) {
    return match(s, re) ? last_word(substr(s, RSTART, RLENGTH)) : ""
}

# Checks one whole SQL statement (lowercase, lines joined with spaces) for risky patterns.
function check_statement(s, line,   t, w) {
    if (s ~ /^[ \t]*create[ \t]+(unique[ \t]+)?index/) {
        t = table_after(s, ON_TABLE)
        # An index on a table created in the same changeset has nothing to block.
        if (s !~ /concurrently/ && !(t in created)) print "blocking-index|" line "|" t
        return
    }
    if (s ~ /^[ \t]*drop[ \t]+table/) {
        print "drop-table|" line "|" table_after(s, DROP_TABLE)
        return
    }
    if (s !~ /^[ \t]*alter[ \t]+table/) return

    t = table_after(s, ALTER_TABLE)
    if (s ~ /[ \t,]drop[ \t]+column/) {
        print "drop-column|" line "|" t
    } else if (match(s, /[ \t,]drop[ \t]+(if[ \t]+exists[ \t]+)?[a-z0-9_"]+/)) {
        # COLUMN is optional in ALTER TABLE t DROP col; skip DROP CONSTRAINT, DROP DEFAULT, DROP NOT NULL, ...
        w = last_word(substr(s, RSTART, RLENGTH))
        if (w !~ /^(constraint|default|not|identity|expression)$/) print "drop-column|" line "|" t
    }
    if (s ~ /alter[ \t]+(column[ \t]+)?[a-z0-9_"]+[ \t]+(set[ \t]+data[ \t]+)?type[ \t]/)
        print "change-column-type|" line "|" t
    if (s ~ /set[ \t]+not[ \t]+null/)
        print "set-not-null|" line "|" t
    if (s ~ /add[ \t]+(constraint[ \t]+[a-z0-9_"]+[ \t]+)?(foreign[ \t]+key|check)/ && s !~ /not[ \t]+valid/)
        print "validating-constraint|" line "|" t
    if (s ~ /add[ \t]+(constraint[ \t]+[a-z0-9_"]+[ \t]+)?(unique|primary[ \t]+key)/ && s !~ /using[ \t]+index/)
        print "unique-constraint-without-index|" line "|" t
}

BEGIN {
    CONCURRENT  = "(create|drop)[ \t]+(unique[ \t]+)?index[ \t]+concurrently"
    TABLE_NAME  = "[a-z0-9_.\"]+"
    CREATE_TABLE = "create[ \t]+table[ \t]+(if[ \t]+not[ \t]+exists[ \t]+)?" TABLE_NAME
    ALTER_TABLE = "alter[ \t]+table[ \t]+((only|if[ \t]+exists)[ \t]+)*" TABLE_NAME
    DROP_TABLE  = "drop[ \t]+table[ \t]+(if[ \t]+exists[ \t]+)?" TABLE_NAME
    ON_TABLE    = "[ \t]on[ \t]+(only[ \t]+)?" TABLE_NAME
}

{ l = tolower($0) }

l ~ /^--changeset[ \t]/ {
    end_changeset()
    cs_line = FNR; cs_id = $2; has_rollback = 0; concurrent = 0
    no_txn = (l ~ /runintransaction:false/)
    no_split = (l ~ /splitstatements:false/)
    split("", created)
    next
}

l ~ /^--rollback([ \t]|$)/ || l ~ /^\/\*[ \t]*liquibase[ \t]+rollback/ {
    end_statement()
    has_rollback = 1
    if (l ~ CONCURRENT) concurrent = 1
    next
}

l ~ /^[ \t]*--/ || l ~ /^[ \t]*$/ { next }

l ~ CONCURRENT { concurrent = 1 }

match(l, CREATE_TABLE) {
    table = last_word(substr(l, RSTART, RLENGTH))
    created[table] = 1
}

match(l, ALTER_TABLE) {
    table = last_word(substr(l, RSTART, RLENGTH))
}

l ~ /(^|[ \t])references[ \t]/ {
    column = ""
    if (match(l, /foreign[ \t]+key[ \t]*\([ \t]*[a-z0-9_"]+/)) {
        # CONSTRAINT fk FOREIGN KEY (col) REFERENCES ...
        column = substr(l, RSTART, RLENGTH)
        sub(/.*\([ \t]*/, "", column)
        gsub(/"/, "", column)
    } else if (match(l, /[ \t]add[ \t]+(column[ \t]+)?(if[ \t]+not[ \t]+exists[ \t]+)?[a-z0-9_"]+/)) {
        # ALTER TABLE t ADD [COLUMN] col type REFERENCES ...
        column = last_word(substr(l, RSTART, RLENGTH))
    } else if (match(l, /^[ \t]*[a-z0-9_"]+/)) {
        # col type REFERENCES ... inside CREATE TABLE
        column = substr(l, RSTART, RLENGTH)
        gsub(/[ \t"]/, "", column)
    }
    if (table != "" && column != "") print "fk|" FNR "|" table "|" column
}

# Collect statement text until its semicolon, then check the whole statement.
cs_line {
    if (stmt == "") stmt_line = FNR
    stmt = stmt " " l
    if (l ~ /;/) end_statement()
}

END { end_changeset() }
