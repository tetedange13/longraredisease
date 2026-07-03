BEGIN {
    # MEMO: awk vars 'callers_str' and 'svtype' should be defined through "ext.args = '-v sample_name= [...]'"
    # Split comma-separated callers string into array
    split(callers_str, callers_arr, ",")
    delete combo_counter
    FS = "\t"
    OFS = "\t"

    # Priority order for genotype tie-breaking
    priority["1/1"] = 3
    priority["0/1"] = 2
    priority["1/0"] = 1
    priority["0/0"] = 0
}

/^##/ { print; next }

/^#CHROM/ {
    print "#CHROM", "POS", "ID", "REF", "ALT", "QUAL", "FILTER", "INFO", "FORMAT", sample_name
    next
}

{
    # --- Extract SUPP_VEC (unchanged) ---
    supp_vec = ""
    split($8, info_fields, ";")
    for (i in info_fields) {
        if (info_fields[i] ~ /^SUPP_VEC=/) {
            split(info_fields[i], tmp, "=")
            supp_vec = tmp[2]
        }
        if (info_fields[i] ~ /^SVTYPE=/) {
            split(info_fields[i], tmp2, "=")
            svtype = tmp2[2]
        }
    }
    if (supp_vec == "") next

    # --- Build supporting callers list (unchanged) ---
    supporting_callers = ""
    for (j = 1; j <= length(supp_vec); j++) {
        bit = substr(supp_vec, j, 1)
        if (bit == "1" && j <= length(callers_arr)) {
            supporting_callers = (supporting_callers == "" ? callers_arr[j] : supporting_callers "." callers_arr[j])
        }
    }
    if (supporting_callers == "") next

    # --- Create new ID and increment counter ---
    combo_key = supporting_callers "." svtype
    if (!(combo_key in combo_counter)) combo_counter[combo_key] = 0
    combo_counter[combo_key]++
    $3 = combo_key "." combo_counter[combo_key]

    # --- Find DR and DV positions in the FORMAT field ---
    dr_idx = 0
    dv_idx = 0
    split($9, fmt_tags, ":")
    for (t = 1; t <= length(fmt_tags); t++) {
        if (fmt_tags[t] == "DR") dr_idx = t
        if (fmt_tags[t] == "DV") dv_idx = t
    }

    # --- Process all samples: GT consensus + collect DR/DV values ---
    delete gt_counts
    delete dr_counts
    delete dv_counts
    total_valid = 0

    for (k = 10; k <= NF; k++) {
        split($k, gt_fields, ":")
        gt = gt_fields[1]
        if (gt != "./." && gt != ".") {
            gt_counts[gt]++
            total_valid++

            # Collect DR value if present and numeric
            if (dr_idx > 0) {
                dr_val = gt_fields[dr_idx]
                if (dr_val ~ /^[0-9]+$/) {
                    dr_counts[dr_val]++
                }
            }
            # Collect DV value if present and numeric
            if (dv_idx > 0) {
                dv_val = gt_fields[dv_idx]
                if (dv_val ~ /^[0-9]+$/) {
                    dv_counts[dv_val]++
                }
            }
        }
    }

    # --- Determine consensus GT ---
    consensus_gt = "./."
    if (total_valid > 0) {
        max_count = 0
        best_gt = ""
        for (gt in gt_counts) {
            count = gt_counts[gt]
            if (count > max_count) {
                max_count = count
                best_gt = gt
            } else if (count == max_count) {
                if (gt in priority && best_gt in priority && priority[gt] > priority[best_gt]) {
                    best_gt = gt
                }
            }
        }
        if (best_gt != "") consensus_gt = best_gt
    }

    # --- Determine consensus DR (mode) ---
    consensus_dr = 0   # default if no valid values
    if (length(dr_counts) > 0) {
        max_dr_count = 0
        for (val in dr_counts) {
            if (dr_counts[val] > max_dr_count) {
                max_dr_count = dr_counts[val]
                consensus_dr = val
            } else if (dr_counts[val] == max_dr_count && val > consensus_dr) {
                # tie-break: pick the larger numeric value (arbitrary but deterministic)
                consensus_dr = val
            }
        }
    }

    # --- Determine consensus DV (mode) ---
    consensus_dv = 0
    if (length(dv_counts) > 0) {
        max_dv_count = 0
        for (val in dv_counts) {
            if (dv_counts[val] > max_dv_count) {
                max_dv_count = dv_counts[val]
                consensus_dv = val
            } else if (dv_counts[val] == max_dv_count && val > consensus_dv) {
                consensus_dv = val
            }
        }
    }

    # --- Set new FORMAT and output ---
    $9 = "GT:DR:DV"

    for (col = 1; col <= 9; col++) {
        printf "%s", $col
        if (col < 9) printf "\t"
    }
    printf "\t%s:%s:%s\n", consensus_gt, consensus_dr, consensus_dv
}
