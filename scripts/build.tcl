#@Note Read Tcl parameters
#
#@param num         Parameter number
#@default_value     Default value if there is no parameter with requested number
#@retval            Parameter value
proc read_param {num default_value} {
    if {[llength $::argv] > $num} {
        puts "Script parameter ${num} is [lindex $::argv $num]"
        return [lindex $::argv $num]
    } else {
        return ${default_value}
    }
}

#Get script path
set script_path     [file dirname [file normalize [info script]]]

#Get configuration from script parameters
set board_name      [read_param 0 "zynq_mini_7020"]
set build_type      [read_param 1 "create_bd"]
set prj_folder_name [read_param 2 "vivado_bd"]
set prj_name        ${board_name}

#Configure project
set prj_path        [file normalize ${script_path}/../${prj_folder_name}]
set board_path      [file normalize ${script_path}/../board/${board_name}]
set ip_repo_path    [file normalize ${script_path}/../ip_repo]

#Sourse scripts
source ${board_path}/platform.tcl
#Aux. processes
source ${script_path}/aux_proc.tcl
source ${script_path}/create_bd.tcl

#Read part
set part_name       [platfrom_get_part]


#Create project
create_project ${prj_name} ${prj_path} -part ${part_name} -force

#Add constraints
add_files -fileset constrs_1 -norecurse [findFiles ${board_path} "*.xdc"]

#Add IP repository
if {[file exist ${ip_repo_path}]} {
    set prj_iprepo_list [get_property ip_repo_paths [current_project]]
    lappend prj_iprepo_list ${ip_repo_path}
    set_property  ip_repo_paths ${prj_iprepo_list} [current_project]
    update_ip_catalog
}

#Create block design or use pure HDL (FPGA only)
if {${build_type} == "create_bd"} {
    create_bd ${board_path}
} else {
    #HDL design
    add_files -norecurse ${board_path}/arty_a7_rtl.sv
    update_compile_order -fileset sources_1
}

#Create xcleanup.bat file
create_prj_cleanup ${prj_path} ${prj_name}

##Run build
# launch_runs impl_1 -to_step write_bitstream -jobs 16
# wait_on_run impl_1

exit