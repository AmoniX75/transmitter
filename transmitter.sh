#!/bin/bash

tx=false
freq=145775000
bw=12500
mod=fm
gain=0
sql=50
ppm=0


function start_sdr() {
    killall -q -9 rtl_fm aplay
    rtl_fm -g $gain -M $mod -l $sql -f $freq -s $bw -p $ppm -E dc 2> /dev/null \
    | aplay -q -r $bw -c 1 -f s16_le -t raw &> /dev/null & disown
}

function help() {
    clear
    echo "Transmitter - réalisé par Guillaume PLC"
    echo "---------------------------------------------------"
    echo "  t       : Start/Stop transmitting"
    echo "  n       : Generate BF sine signal"
    echo "  f       : Modify frequency"
    echo "  b       : Modify rx bandwidth"
    echo "  g       : Modify rx gain"
    echo "  s       : Modify rx squelch"
    echo "  m       : Modify modulation" 
    echo "  p       : Modify rx PPM"   
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
    | ./rpitx/csdr convert_i16_f \
    | ./rpitx/csdr gain_ff 7000 | csdr convert_f_samplerf 20833 \
	| sudo ./rpitx/rpitx -i /dev/stdin -m RF -a 14 -f $(($freq/1000)) &> /dev/null & disown
}

function gen_sine() {
    help
    read -p "Frequency in hertz : " bf
    read -p "Duration in second : " sec
    tx=true
    help
    killall rtl_fm aplay -9
    ffmpeg -nostdin -hide_banner -loglevel panic -f lavfi -i "sine=frequency=$bf:sample_rate=48000:duration=$sec" -ab 16k -f wav -y /dev/stdout 2> /dev/null \
    | ./rpitx/csdr convert_i16_f \
    | ./rpitx/csdr gain_ff 7000 | csdr convert_f_samplerf 20833 \
	| sudo ./rpitx/rpitx -i /dev/stdin -m RF -a 14 -f $(($freq/1000)) &> /dev/null & disown
    sleep $sec
    listen
}

function mod_freq() {
    help
    read -p "Frequency in hertz : " freq
    listen
}

function mod_bandwidth() {
    help
    read -p "Bandwidth in hertz : " bw
    listen
}

function mod_ppm() {
    help
    read -p "PPM : " ppm
    listen
}

function mod_modulation() {
    help
    read -p "Modulation (fm|am|wbfm|usb|lsb|raw) : " mod
    listen
}

function mod_gain() {
    help
    read -p "Gain (0=auto) : " gain
    listen
}

function mod_sql() {
    help
    read -p "Squelch (0-1000) : " sql
    listen
}


function update_program() {
    rm rpitx transmitter.sh -rf
    git clone https://github.com/AmoniX75/transmitter.git
    mv transmitter/install.sh .
    mv transmitter/transmitter.sh .
    rm transmitter -rf
    ./install.sh
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
    elif [ "$key" = "m" ]; then mod_modulation;
    elif [ "$key" = "b" ]; then mod_bandwidth;
    elif [ "$key" = "p" ]; then mod_ppm;
    elif [ "$key" = "g" ]; then mod_gain;
    elif [ "$key" = "s" ]; then mod_sql;
    elif [ "$key" = "n" ]; then gen_sine;   
    elif [ "$key" = "u" ]; then update_program;    
    elif [ "$key" = "q" ]; then quit;
    fi    
done