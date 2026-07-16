BEGIN {
    OFS="\t"
    keep["SVTYPE"]          = 1
    keep["SVLEN"]           = 1
    keep["END"]             = 1
    keep["END2"]            = 1
    keep["CHR2"]            = 1
    keep["SUPP"]            = 1
    keep["SUPP_VEC"]        = 1
    keep["STRANDS"]         = 1
    keep["NumCollapsed"]    = 1
    keep["NumConsolidated"] = 1
}
/^##INFO=<ID=END,/ {
    print
    print "##INFO=<ID=END2,Number=1,Type=Integer,Description=\"Mate end coordinate for BND/TRA/INV records\">"
    next
}
/^##INFO=<ID=SUPP,/ {
    print "##INFO=<ID=SUPP,Number=1,Type=Integer,Description=\"Number of samples supporting the variant\">"
    print "##FILTER=<ID=1,Description=\"1 caller supporting the variant\">"
    print "##FILTER=<ID=2,Description=\"2 callers supporting the variant\">"
    print "##FILTER=<ID=3,Description=\"3 callers supporting the variant\">"
    print "##FILTER=<ID=4,Description=\"4 callers supporting the variant\">"
    print "##FILTER=<ID=5,Description=\"5 callers supporting the variant\">"
    print "##FILTER=<ID=6,Description=\"6 callers supporting the variant\">"
    print "##FILTER=<ID=7,Description=\"7 callers supporting the variant\">"
    next
}
/^#/ { print; next }
{
    if ($8 ~ /SVTYPE=(BND|TRA|INV)/) {
        sub(/^END=/, "END2=", $8)
        gsub(/;END=/, ";END2=", $8)
    } else {
        sub(/^CHR2=[^;]*;?/, "", $8)
        gsub(/;CHR2=[^;]*/,  "", $8)
        if ($8 == "") $8 = "."
    }
    n = split($8, fields, ";")
    new_info = ""
    for (i = 1; i <= n; i++) {
        eq = index(fields[i], "=")
        key = (eq > 0) ? substr(fields[i], 1, eq - 1) : fields[i]
        value = (eq > 0) ? substr(fields[i], eq+1, length(fields[i])) : fields[i]
        if (key in keep) {
            new_info = (new_info == "") ? fields[i] : new_info ";" fields[i]
        }
        if (key == "SUPP") {
            saved_supp = value
        }
    }
    $2 = ($2<0) ? 0 : $2
    $8 = (new_info == "") ? "." : new_info
    $3 = "."
    $7 = saved_supp
    print
}
