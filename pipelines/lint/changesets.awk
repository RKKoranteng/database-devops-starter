# Reads one Liquibase formatted SQL file and prints one finding per line:
#   no-rollback|<line>|<changeset id>     changeset without a rollback
#   concurrent|<line>|<changeset id>      CONCURRENTLY used without runInTransaction:false
#   fk|<line>|<table>|<column>            column that references another table
# Portable awk (gawk and mawk), so it runs the same locally and on GitHub runners.

function end_changeset() {
    if (cs_line && !has_rollback) print "no-rollback|" cs_line "|" cs_id
    if (cs_line && concurrent && !no_txn) print "concurrent|" cs_line "|" cs_id
}

# Last word of s, without quotes or schema prefix: 'create table if not exists public.orders' -> 'orders'
function last_word(s) {
    sub(/.*[ \t]/, "", s)
    gsub(/"/, "", s)
    sub(/.*\./, "", s)
    return s
}

BEGIN { CONCURRENT = "(create|drop)[ \t]+(unique[ \t]+)?index[ \t]+concurrently" }

{ l = tolower($0) }

l ~ /^--changeset[ \t]/ {
    end_changeset()
    cs_line = FNR; cs_id = $2; has_rollback = 0; concurrent = 0
    no_txn = (l ~ /runintransaction:false/)
    next
}

l ~ /^--rollback([ \t]|$)/ || l ~ /^\/\*[ \t]*liquibase[ \t]+rollback/ {
    has_rollback = 1
    if (l ~ CONCURRENT) concurrent = 1
    next
}

l ~ /^[ \t]*--/ { next }

l ~ CONCURRENT { concurrent = 1 }

match(l, /create[ \t]+table[ \t]+(if[ \t]+not[ \t]+exists[ \t]+)?[a-z0-9_."]+/) {
    table = last_word(substr(l, RSTART, RLENGTH))
}

match(l, /alter[ \t]+table[ \t]+((only|if[ \t]+exists)[ \t]+)*[a-z0-9_."]+/) {
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

END { end_changeset() }
