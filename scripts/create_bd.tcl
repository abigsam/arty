proc create_bd {board_path} {
    set bd_name "design_1"
    create_bd_design ${bd_name}
    save_bd_design


    #Validate *************************************************************************************
    validate_bd_design
    save_bd_design

    #Make wrapper *********************************************************************************
    set wrapper_path [make_wrapper -fileset sources_1 -files [ get_files -norecurse ${bd_name}.bd] -top]
    add_files -norecurse -fileset sources_1 ${wrapper_path}
    return [file tail ${wrapper_path}]; #Return wrapper file name
}