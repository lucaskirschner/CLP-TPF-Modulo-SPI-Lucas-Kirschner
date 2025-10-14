onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+vio -L xil_defaultlib -L secureip -O5 xil_defaultlib.vio

do {wave.do}

view wave
view structure

do {vio.udo}

run -all

endsim

quit -force
