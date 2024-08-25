proc bd_add_mig {board_path mig_name} {
    set mig_prj_path [file normalize ${board_path}/mig.prj]
    set mig_ip [create_bd_cell -type ip -vlnv xilinx.com:ip:mig_7series:4.2 ${mig_name}]
    set_property CONFIG.XML_INPUT_FILE ${mig_prj_path} [get_bd_cells ${mig_ip}]
    #
    connect_bd_net [get_bd_pins ${mig_ip}/ui_addn_clk_0] [get_bd_pins ${mig_ip}/clk_ref_i]
    #
    create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR3
    connect_bd_intf_net [get_bd_intf_pins ${mig_name}/DDR3] [get_bd_intf_ports DDR3]
}

# INFO:
# https://digilent.com/reference/programmable-logic/guides/microblaze-adding-ddr
# https://digilent.com/reference/programmable-logic/arty-a7/reference-manual


proc create_microblaze_bd {board_path} {
    #Configure microblaze project
    set use_axi_led_buttons {1}; #use (1) or not (0) AXI GPIO for 4 LEDs on board and 4 buttons
    set use_axi_uart        {1}; #use (1) or not (0) AXU UART connected to the UART-USB converter
    set uart_baud           {115200}; #UART baudrate (if use_axi_uart > 0)
    #
    set bd_name "design_1"
    set mig_name "mig0"
    set microblaze_name "microblaze0"
    
    #Create BD
    create_bd_design ${bd_name}
    
    #Create ports
    create_bd_port -dir I -type clk -freq_hz 100000000 CLK100MHZ
    create_bd_port -dir I -type rst ck_rst
    if {${use_axi_led_buttons} > 0} {
        create_bd_port -dir O -from 3 -to 0 led
        create_bd_port -dir I -from 3 -to 0 btn
    }
    if {${use_axi_uart} > 0} {
        create_bd_port -dir I uart_rxd_out
        create_bd_port -dir O uart_txd_in
    }
    save_bd_design

    #Add MIG
    bd_add_mig ${board_path} ${mig_name}
    connect_bd_net [get_bd_pins ${mig_name}/sys_clk_i] [get_bd_ports CLK100MHZ]
    apply_bd_automation -rule xilinx.com:bd_rule:board -config { Manual_Source {/ck_rst (ACTIVE_LOW)}}  [get_bd_pins ${mig_name}/sys_rst]
    save_bd_design

    #Add Microblaze
    create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 ${microblaze_name}
    apply_bd_automation -rule xilinx.com:bd_rule:microblaze -config " \
        axi_intc {1} \
        axi_periph {Enabled} \
        cache {8KB} \
        clk {/mig0/ui_clk (81 MHz)} \
        cores {1} \
        debug_module {Debug Only} \
        ecc {None} \
        local_mem {8KB} \
        preset {None} " \
    [get_bd_cells ${microblaze_name}]
    set_property CONFIG.C_AREA_OPTIMIZED {1} [get_bd_cells ${microblaze_name}]
    set axi_interc_name "${microblaze_name}_axi_periph"
    set microb_irq_concat_name "${microblaze_name}_xlconcat"
    save_bd_design

    #Connect MIG to Microblaze via AXI
    apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config " \
        Clk_master {/${mig_name}/ui_clk (81 MHz)} \
        Clk_slave {/${mig_name}/ui_clk (81 MHz)} \
        Clk_xbar {/${mig_name}/ui_clk (81 MHz)} \
        Master {/${microblaze_name} (Cached)} \
        Slave {/${mig_name}/S_AXI} \
        ddr_seg {Auto} \
        intc_ip {New AXI SmartConnect} \
        master_apm {0}"  \
    [get_bd_intf_pins ${mig_name}/S_AXI]
    save_bd_design

    #Add AXI GPIO for on-board LEDs and buttons
    if {${use_axi_led_buttons} > 0} {
        create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_led_but
        set_property -dict [list \
            CONFIG.C_ALL_INPUTS_2 {1} \
            CONFIG.C_ALL_OUTPUTS {1} \
            CONFIG.C_GPIO2_WIDTH {4} \
            CONFIG.C_GPIO_WIDTH {4} \
            CONFIG.C_IS_DUAL {1} \
        ] [get_bd_cells axi_gpio_led_but]
        #
        connect_bd_net [get_bd_pins /axi_gpio_led_but/gpio_io_o] [get_bd_ports led]
        connect_bd_net [get_bd_pins /axi_gpio_led_but/gpio2_io_i] [get_bd_ports btn]
        #
        apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config " \
            Clk_master {/${mig_name}/ui_clk (81 MHz)} \
            Clk_slave {Auto} \
            Clk_xbar {/${mig_name}/ui_clk (81 MHz)} \
            Master {/${microblaze_name} (Periph)} \
            Slave {/axi_gpio_led_but/S_AXI} \
            ddr_seg {Auto} \
            intc_ip {/${axi_interc_name}} \
            master_apm {0}"  \
        [get_bd_intf_pins axi_gpio_led_but/S_AXI]
    }

    #Add AXI UAARTLITE if need
    if {${use_axi_uart} > 0} {
        set axi_uart_name "axi_uart_usb"
        create_bd_cell -type ip -vlnv xilinx.com:ip:axi_uartlite:2.0 ${axi_uart_name}
        set_property CONFIG.C_BAUDRATE ${uart_baud} [get_bd_cells ${axi_uart_name}]
        #
        connect_bd_net [get_bd_pins /${axi_uart_name}/rx] [get_bd_ports uart_rxd_out]
        connect_bd_net [get_bd_pins /${axi_uart_name}/tx] [get_bd_ports uart_txd_in]
        connect_bd_net [get_bd_pins ${axi_uart_name}/interrupt] [get_bd_pins ${microb_irq_concat_name}/In0]
        #
        apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config " \
            Clk_master {/${mig_name}/ui_clk (81 MHz)} \
            Clk_slave {Auto} \
            Clk_xbar {/${mig_name}/ui_clk (81 MHz)} \
            Master {/${microblaze_name} (Periph)} \
            Slave {/${axi_uart_name}/S_AXI} \
            ddr_seg {Auto} \
            intc_ip {/${axi_interc_name}} \
            master_apm {0}"  \
        [get_bd_intf_pins ${axi_uart_name}/S_AXI]
    }


    #Validate *************************************************************************************
    validate_bd_design
    save_bd_design

    #Make wrapper *********************************************************************************
    set wrapper_path [make_wrapper -fileset sources_1 -files [ get_files -norecurse ${bd_name}.bd] -top]
    add_files -norecurse -fileset sources_1 ${wrapper_path}
    return [file tail ${wrapper_path}]; #Return wrapper file name
}