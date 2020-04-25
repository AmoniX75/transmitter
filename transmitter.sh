#!/bin/bash

tx=false
freq=145775000
mod=fm
ppm=0

#read -p "Modulation (fm|am|usb|lsb) : " mod
#read -p "PPM : " ppm

function start_sdr() {
    rtl_fm -M $mod -f $freq -s 12500 2> /dev/null \
    | aplay -r 12500 -c 1 -f s16_le -t raw &> /dev/null & disown
}

function help() {
    clear
    echo "Transmitter - réalisé par Guillaume PLC"
    echo "---------------------------------------------------"
    echo "  t       : Start/Stop transmitting"
    echo "  s       : Generate BF sine signal"
    echo "  f       : Modify frequency"
    echo "  m       : Modify modulation" 
    echo "  p       : Modify PPM"   
    echo "  q       : Quit this program"
    echo "--------------------------------------------------"
    echo "Frequency : $freq - Modulation : $mod - Transmitting : $tx"
    echo ""
}

function listen() {
    tx=false        
    help
    start_sdr
    killall arecord rpttx &> /dev/null
}

function transmit() {
    tx=true
    help
    killall rtl_fm aplay -9
 	arecord --format=S16_LE --rate=48000 --file-type=raw /dev/stdout 2> /dev/null \
    | csdr convert_i16_f \
    | csdr gain_ff 7000 | csdr convert_f_samplerf 20833 \
	| sudo ../rpitx -i /dev/stdin -m RF -a 14 -f $(($freq/1000)) &> /dev/null & disown
}

function gen_sine() {
    help
    read -p "Frequency in hertz : " bf
    read -p "Duration in second : " sec
    tx=true
    help
    ffmpeg -nostdin -hide_banner -loglevel panic -f lavfi -i "sine=frequency=$bf:sample_rate=48000:duration=$sec" -ab 16k -f wav -y /dev/stdout 2> /dev/null \
    | csdr convert_i16_f \
    | csdr gain_ff 7000 | csdr convert_f_samplerf 20833 \
	| sudo ../rpitx -i /dev/stdin -m RF -a 14 -f $(($freq/1000)) &> /dev/null & disown
    sleep $sec
    listen
}

function mod_freq() {
    help
    read -p "Frequency in hertz : " freq
    listen
}

function quit() {
    clear
    killall rtl_fm aplay rpitx arecord -9 &> /dev/null
    exit 0
}


trap "quit" SIGINT

listen

while true
do    	
    read -rsn1 key
    if [ "$key" = "t" ] && [ $tx = false ]; then transmit;
    elif [ "$key" = "t" ] && [ $tx = true ]; then listen;
    elif [ "$key" = "f" ]; then mod_freq;    
    elif [ "$key" = "s" ]; then gen_sine;    
    elif [ "$key" = "q" ]; then quit;
    fi    
done