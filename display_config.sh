#!/bin/bash
# Raspberry Pi Internet Radio display configuration for analysis
# $Id: display_config.sh,v 1.46 2023/06/07 13:13:46 bob Exp $
#
# Author : Bob Rathbone
# Site   : http://www.bobrathbone.com
#
# This program is diagnostic to display the OS and radio configuration
#
# License: GNU V3, See https://www.gnu.org/copyleft/gpl.html
#
# Disclaimer: Software is provided as is and absolutly no warranties are implied or given.
#            The authors shall not be liable for any loss or damage however caused.
#

# This script requires an English locale(C)
export LC_ALL=C

# Version 7.5 onwards allows any user with sudo permissions to install the software
USR=$(logname)
GRP=$(id -g -n ${USR})

DIR=/usr/share/radio
LOG=${DIR}/config.log
BOOTCONFIG=/boot/config.txt
MPD_CONFIG=/etc/mpd.conf
OS_RELEASE=/etc/os-release
DEBIAN_VERSION=/etc/debian_version
CONFIG=/etc/radiod.conf
RADIOLIB=/var/lib/radiod
ASOUND=/etc/asound.conf
SOUND_CARD=0
EQUALIZER_CMD=${DIR}/equalizer.cmd
EMAIL=bob@bobrathbone.com
AUTOSTART=/home/${USR}/.config/lxsession/LXDE-pi/autostart
MPDLIB=/var/lib/mpd

# Get OS release ID
function release_id
{
    VERSION_ID=$(grep VERSION_ID $OS_RELEASE)
    arr=(${VERSION_ID//=/ })
    ID=$(echo "${arr[1]}" | tr -d '"')
    ID=$(expr ${ID} + 0)
    echo ${ID}
}

if [[ ! -d ${DIR} ]]; then
    echo "Error: Radio software not installed - Exiting."
    exit 1
fi

echo "Configuration log for $(hostname) $(date)" | tee ${LOG}
grep ^Release ${DIR}/README | tee -a ${LOG}
echo "IP address: $(hostname -I)"  | tee -a ${LOG}

# Display OS
echo | tee -a ${LOG}
echo "OS Configuration" | tee -a ${LOG}
echo "----------------" | tee -a ${LOG}
cat ${OS_RELEASE} | tee -a ${LOG}
echo "Debian version $(cat ${DEBIAN_VERSION})" | tee -a ${LOG}

echo | tee -a ${LOG}
echo "Kernel version " | tee -a ${LOG}
echo "--------------" | tee -a ${LOG}
uname -a  | tee -a ${LOG}
echo | tee -a ${LOG}

echo "User $(id -u -n)" | tee -a ${LOG}
echo "-----------" | tee -a ${LOG}
id | tee -a ${LOG}
echo | tee -a ${LOG}


# Check for X-Windows graphic radio installation
echo | tee -a ${LOG}
echo "Desktop installation" | tee -a ${LOG}
echo "--------------------" | tee -a ${LOG}
if [[ -f /usr/bin/startx ]]; then
	echo "X-Windows appears to be installed" | tee -a ${LOG}
    if [[ -f ${AUTOSTART} ]]; then
        entry=$(grep -i "radio" ${AUTOSTART})
        if [[ $? == 0 ]]; then
            if [[ ${entry:0:1} == "#" ]]; then
                echo "Graphic version of the radio is disabled in ${AUTOSTART}" | tee -a ${LOG}
            else
                echo "Graphic version of the radio configured in ${AUTOSTART}" | tee -a ${LOG}
            fi
            echo ${entry} | tee -a ${LOG}
        else
            echo "Graphic versions of the radio not configured in ${AUTOSTART}" | tee -a ${LOG}
        fi
    else
        echo "Error - No ${AUTOSTART} file found"  | tee -a ${LOG}
    fi
else
	echo "X-Windows is not installed" | tee -a ${LOG}
	echo "Probaly Raspbian-Lite installed" | tee -a ${LOG}
fi 

# Display radio software version
echo | tee -a ${LOG}
echo "Radio version" | tee -a ${LOG}
echo "-------------" | tee -a ${LOG}
sudo ${DIR}/radiod.py version | tee -a ${LOG}

echo | tee -a ${LOG}
echo "Patches" | tee -a ${LOG}
echo "-------" | tee -a ${LOG}
ls ${DIR}/radiod-patch*.gz >/dev/null 2>&1
if [[ $? == 0 ]]; then
    for f in $(ls ${DIR}/radiod-patch*.gz)
    do
        basename ${f}
    done
else
    echo "No patches found" | tee -a ${LOG}
fi

# Display MPD configuration
echo | tee -a ${LOG}
echo "MPD Configuration" | tee -a ${LOG}
echo "-----------------" | tee -a ${LOG}

mpd -V | grep Daemon | tee -a ${LOG}
if [[ $? -ne 0 ]];then
    mpd -V | tee -a ${LOG}
fi
mpc help | grep -i "version:"
if [[ $? -ne 0 ]];then
    "Error: mpc not found"  | tee -a ${LOG}
fi
echo | tee -a ${LOG}

if [[ -f  ${MPD_CONFIG} ]]; then
	grep -A 8 ^audio_output  ${MPD_CONFIG} | tee -a ${LOG}
else
	echo "FATAL ERROR!" | tee -a ${LOG}
	echo "MPD (Music Player Daemon) has not been installed" | tee -a ${LOG}
	echo "Install packages mpd,mpc and python3-mpd" | tee -a ${LOG}
	echo "and rerun configure_radio.sh to set-up the radio software" | tee -a ${LOG}
	exit 1
fi

# Display MPD outputs
echo | tee -a ${LOG}
echo "MPD outputs" | tee -a ${LOG}
echo "-----------" | tee -a ${LOG}
mpc outputs | tee -a ${LOG}

if [[ -f /usr/bin/pulseaudio ]];then
	echo | tee -a ${LOG}
	echo "The pulseaudio package appears to be installed" | tee -a ${LOG}
fi

# Display boot configuration
echo | tee -a ${LOG}
echo ${BOOTCONFIG} | tee -a ${LOG}
echo "----------------" | tee -a ${LOG}
grep ^hdmi ${BOOTCONFIG} | tee -a ${LOG}
grep ^dtparam=audio ${BOOTCONFIG} | tee -a ${LOG}
grep ^dtparam= ${BOOTCONFIG} | tee -a ${LOG}
grep ^dtoverlay ${BOOTCONFIG} | tee -a ${LOG}
grep ^gpio=..=op,dh ${BOOTCONFIG} | tee -a ${LOG}

# Display configuration
echo | tee -a ${LOG}
echo "Radio configuration" | tee -a ${LOG}
echo "-------------------" | tee -a ${LOG}
sudo ${DIR}/config_class.py | tee -a  ${LOG}
echo | tee -a ${LOG}
${DIR}/wiring.py | tee -a  ${LOG}
echo "---------------------------------------" | tee -a ${LOG}

# Display sound devices
AUDIO_OUT=$(grep "audio_out=" ${CONFIG}) | tee -a ${LOG}
echo | tee -a ${LOG}
echo "========= Audio Configuration =========" | tee -a ${LOG}
if [[ ${AUDIO_OUT} =~ bluetooth  ]]; then
    echo ${AUDIO_OUT}  | tee -a ${LOG}
else
    /usr/bin/aplay -l | tee -a ${LOG}
fi
aplay -L | grep -i pulse | tee -a ${LOG}

echo | tee -a ${LOG}
echo "Mixer controls" | tee -a ${LOG}
echo "--------------" | tee -a ${LOG}
if [[ ${AUDIO_OUT} =~ bluetooth  ]]; then
    cmd="amixer -D bluealsa controls"
elif [[ ${AUDIO_OUT} =~ USB  ]]; then
    SOUND_CARD=1
    cmd="amixer -c ${SOUND_CARD} controls 2>$1" | tee -a ${LOG}
else
    cmd="amixer -c ${SOUND_CARD} controls 2>$1" | tee -a ${LOG}
fi
echo "audio_out=${AUDIO_OUT}"
echo ${cmd} | tee -a ${LOG}
${cmd} | tee -a ${LOG}

# Display /etc/asound.conf configuration
if [[ -f ${ASOUND} ]]; then 
	echo | tee -a ${LOG}
	echo "${ASOUND} configuration file" | tee -a ${LOG}
	echo "-----------------------------------" | tee -a ${LOG}
	cat ${ASOUND} | tee -a ${LOG}
fi

echo | tee -a ${LOG}
echo "Equalizer command file (${EQUALIZER_CMD}) "  | tee -a ${LOG}
echo "-------------------------------------------------------" | tee -a ${LOG}
grep lxterminal ${EQUALIZER_CMD}  | tee -a ${LOG}

# Display mixer ID configuration
echo | tee -a ${LOG}
echo "Mixer ID Configuration (${RADIOLIB}/mixer_volume_id)" | tee -a ${LOG}
echo "-------------------------------------------------------" | tee -a ${LOG}
echo "mixer_volume_id=$(cat ${RADIOLIB}/mixer_volume_id)" | tee -a ${LOG}

echo | tee -a ${LOG}
echo "Remote control daemon (irradiod.service)" | tee -a ${LOG}
echo "----------------------------------------" | tee -a ${LOG}

# Display remote control daemon configuration
if [[ -f /lib/systemd/system/irradiod.service ]]; then
    grep ExecStart /lib/systemd/system/irradiod.service | tee -a ${LOG}
    if [[ $(release_id) -lt 10 ]]; then
        sudo ${DIR}/remote_control.py status | tee -a ${LOG}
        sudo ${DIR}/remote_control.py config | tee -a ${LOG}
    else
        sudo ${DIR}/irradiod.py status | tee -a ${LOG}
        sudo ${DIR}/irradiod.py config | tee -a ${LOG}
    fi
else 
    echo "irradiod.service not installed" | tee -a ${LOG}
fi


echo | tee -a ${LOG}
echo "${RADIOLIB} settings" | tee -a ${LOG}
echo "------------------------" | tee -a ${LOG}
for file in ${RADIOLIB}/*
do
    if [[ $(basename ${file}) == "stationlist" ]]; then
        continue
    fi
    if [[ $(basename ${file}) == "language" ]]; then
        continue
    fi
    param=$(head -1 ${file})
    echo "$(basename ${file}): ${param}" | tee -a ${LOG}
done

echo | tee -a ${LOG}
echo "MPD Playlists" | tee -a ${LOG}
echo "-------------" | tee -a ${LOG}
ls -l ${MPDLIB}/playlists

echo | tee -a ${LOG}
echo "Hardware information" | tee -a ${LOG}
echo "--------------------" | tee -a ${LOG}
sudo ${DIR}/display_model.py version | tee -a ${LOG}

echo | tee -a ${LOG}
echo "CPU temperature" | tee -a ${LOG}
echo "-------------" | tee -a ${LOG}
vcgencmd measure_temp | tee -a ${LOG}

echo | tee -a ${LOG}
echo "Network information" | tee -a ${LOG}
echo "-------------------" | tee -a ${LOG}
echo "IP address: $(hostname -I)" | tee -a ${LOG}
echo "IP route:" | tee -a ${LOG}
ip route | tee -a ${LOG}

./display_wifi.sh | tee -a ${LOG}

echo | tee -a ${LOG}
echo "Network Time information" | tee -a ${LOG}
echo "------------------------" | tee -a ${LOG}
timedatectl timesync-status | tee -a ${LOG}

echo | tee -a ${LOG}
echo "=================== End of run =====================" | tee -a ${LOG}
echo | tee -a ${LOG}

# Create tar file
tar -zcf ${LOG}.tar.gz ${LOG} >/dev/null 2>&1

echo "This configuration has been recorded in ${LOG}" 
echo "A compressed tar file has been saved in ${LOG}.tar.gz" | tee -a ${LOG}
echo | tee -a ${LOG}
echo "Send ${LOG}.tar.gz to ${EMAIL} if required" | tee -a ${LOG}
echo | tee -a ${LOG}

# End of script
# set tabstop=4 shiftwidth=4 expandtab
# retab
