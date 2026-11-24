# Fichier     : sim_beh.tcl
# Description : Compilation et simulation comportementale
# --------------------------------------------------------
set work    "/export/tmp/8304_4/Labs/lab2/work"
set srcD    "/export/tmp/8304_4/Labs/lab2/sources"
set top     "riscv_core"
set tb      "${top}_tb"
set wave    "${top}_wave"
set modules [list "riscv_pkg" "riscv_adder" "riscv_pc" "riscv_rf" "riscv_alu" "riscv_eswp" "dpm"]

# Copie du fichier modelsim.ini
vmap -c

# Mise à jour de la librairie de travail
if { [file exists $work] } {
    vdel -all -lib $work
}
vlib $work
vmap work $work

# Compilation
foreach module $modules {
    vcom -2008 -work work $srcD/$module.vhd
}
vcom -2008 -work work $srcD/$top.vhd
vcom -2008 -work work $srcD/$tb.vhd

# Simulation
vsim work.$tb

# Exécution
do $wave.do
run -all