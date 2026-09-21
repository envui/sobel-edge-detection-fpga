#-----------------------------------------------------------------------------
# create_project.tcl -- rebuild the Vivado project for the Sobel HDMI design.
#
# Usage, from the repository root:
#     vivado -mode batch -source scripts/create_project.tcl
# or from the Vivado Tcl console:
#     source scripts/create_project.tcl
#
# The rgb2dvi core is NOT in the stock Vivado IP catalog. Install Digilent's
# vivado-library (https://github.com/Digilent/vivado-library) and point
# DIGILENT_IP at it before running:
#     set env(DIGILENT_IP) C:/Xilinx/vivado-library
#-----------------------------------------------------------------------------

set proj_name  "sobel_hdmi_fpga"
set part       "xc7z010clg400-1"
set board      "digilentinc.com:zybo-z7-10:part0:1.0"

# Repo root, derived from this script's location, so the script works from
# any working directory.
set repo_root [file normalize [file join [file dirname [info script]] ..]]
set build_dir [file join $repo_root build]

puts "INFO: repository root: $repo_root"

if {[file exists $build_dir]} {
    puts "WARNING: $build_dir already exists. Delete it to rebuild from scratch."
    return
}

create_project $proj_name $build_dir -part $part
puts "INFO: created project $proj_name for $part"

# Board file is optional -- the design is constrained by XDC, not by board
# automation, so a missing board definition is not fatal.
if {[catch {set_property board_part $board [current_project]} err]} {
    puts "WARNING: board part $board unavailable; continuing with part-only flow."
}

#-----------------------------------------------------------------------------
# Digilent IP repository (required for rgb2dvi)
#-----------------------------------------------------------------------------
if {[info exists ::env(DIGILENT_IP)]} {
    set dig_ip $::env(DIGILENT_IP)
    puts "INFO: adding IP repository $dig_ip"
    set_property ip_repo_paths $dig_ip [current_project]
    update_ip_catalog -rebuild
} else {
    puts "WARNING: DIGILENT_IP is not set."
    puts "WARNING: rgb2dvi_0.xci will fail to resolve without the Digilent"
    puts "WARNING: vivado-library added as an IP repository."
}

#-----------------------------------------------------------------------------
# RTL sources
#-----------------------------------------------------------------------------
add_files -norecurse [glob [file join $repo_root rtl *.v]]

# Memory init files must travel with the design so $readmemh resolves during
# both synthesis and simulation.
add_files -norecurse [list \
    [file join $repo_root data image.mem] \
    [file join $repo_root data image_small.mem]]
set_property file_type {Memory Initialization Files} \
    [get_files [file join $repo_root data image.mem]]
set_property file_type {Memory Initialization Files} \
    [get_files [file join $repo_root data image_small.mem]]

set_property top top_hdmi_zybo [get_filesets sources_1]

#-----------------------------------------------------------------------------
# Constraints
#-----------------------------------------------------------------------------
add_files -fileset constrs_1 -norecurse \
    [file join $repo_root constraints Zybo-Z7-Master.xdc]

#-----------------------------------------------------------------------------
# Simulation sources
#-----------------------------------------------------------------------------
add_files -fileset sim_1 -norecurse [glob [file join $repo_root sim *.v]]
set_property top tb_top_small [get_filesets sim_1]

#-----------------------------------------------------------------------------
# IP cores
#-----------------------------------------------------------------------------
foreach xci [glob -nocomplain [file join $repo_root ip *.xci]] {
    puts "INFO: importing IP [file tail $xci]"
    if {[catch {import_ip $xci} err]} {
        puts "ERROR: failed to import [file tail $xci]: $err"
    }
}

if {[llength [get_ips]] > 0} {
    upgrade_ip [get_ips]
    generate_target all [get_ips]
}

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts ""
puts "INFO: project ready at [file join $build_dir $proj_name.xpr]"
puts "INFO: synthesis top    : top_hdmi_zybo"
puts "INFO: simulation top   : tb_top_small"
puts ""
puts "INFO: next: launch_runs synth_1 -jobs 4"
puts "INFO:       launch_runs impl_1 -to_step write_bitstream -jobs 4"
