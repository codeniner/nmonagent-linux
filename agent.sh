#!/bin/bash

# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

GATEWAY=$(cat /opt/nmon/gateway)
SERVERKEY=$(cat /opt/nmon/serverkey)

#============
# Functions
#============


function encode() {
	echo "$1" | base64
}

function getOS() {
	if [ -f /etc/lsb-release ]; then
		os_name=$(lsb_release -s -d)
	elif [ -f /etc/debian_version ]; then
		os_name="Debian $(cat /etc/debian_version)"
	elif [ -f /etc/redhat-release ]; then
		os_name=`cat /etc/redhat-release`
	else
		os_name="$(cat /etc/*release | grep '^PRETTY_NAME=\|^NAME=\|^DISTRIB_ID=' | awk -F\= '{print $2}' | tr -d '"' | tac)"
		if [ -z "$os_name" ]; then
			os_name="$(uname -s)"
		fi
	fi
	echo "$os_name"
}

function cpuSpeed() {
	cpu_speed=$(cat /proc/cpuinfo | grep 'cpu MHz' | awk -F\: '{print $2}' | uniq)
	if [ -z "$cpu_speed" ]; then
		cpu_speed=$(lscpu | grep 'CPU MHz' | awk -F\: '{print $2}' | sed -e 's/^ *//g' -e 's/ *$//g')
	fi
	echo "$cpu_speed"
}

function defaultInterface() {
	interface="$(ip route get 4.2.2.1 | grep dev | awk -F'dev' '{print $2}' | awk '{print $1}')"
	if [ -z $interface ]; then
		interface="$(ip link show | grep 'eth[0-9]' | awk '{print $2}' | tr -d ':' | head -n1)"
	fi
	echo "$interface"
}

function activeConnections() {
	if [ -n "$(command -v ss)" ]; then
		active_connections="$(ss -tun | tail -n +2 | wc -l)"
	else
		active_connections="$(netstat -tun | tail -n +3 | wc -l)"
	fi
	echo "$active_connections"
}

function pingLatency() {
	ping_google="$(ping -B -w 2 -n -c 2 google.com | grep rtt | awk -F '/' '{print $5}')"
	echo "$ping_google"
}


# agent version
agent_version="1.0"
POST="$POST{agent_version}$agent_version{/agent_version}"

# serverkey
serverkey=$(cat /opt/nmon/serverkey)
POST="$POST{serverkey}$serverkey{/serverkey}"

# serverkey
gateway=$(cat /opt/nmon/gateway)
POST="$POST{gateway}$gateway{/gateway}"

# hostname
hostname=$(hostname)
POST="$POST{hostname}$hostname{/hostname}"

# kernel
kernel=$(uname -r)
POST="$POST{kernel}$kernel{/kernel}"

# time
time=$(date +%s)
POST="$POST{time}$time{/time}"

# OS
os=$(getOS)
POST="$POST{os}$os{/os}"

# OS Arch
os_arch=`uname -m`","`uname -p`
POST="$POST{os_arch}$os_arch{/os_arch}"

# CPU Model
cpu_model=$(cat /proc/cpuinfo | grep 'model name' | awk -F\: '{print $2}' | uniq)
POST="$POST{cpu_model}$cpu_model{/cpu_model}"

# CPU Cores
cpu_cores=$(cat /proc/cpuinfo | grep processor | wc -l)
POST="$POST{cpu_cores}$cpu_cores{/cpu_cores}"

# CPU Speed
cpu_speed=$(cpuSpeed)
POST="$POST{cpu_speed}$cpu_speed{/cpu_speed}"

# CPU Load
cpu_load=$(cat /proc/loadavg | awk '{print $1","$2","$3}')
POST="$POST{cpu_load}$cpu_load{/cpu_load}"

##### CPU Info
cpu_info=$(grep -i cpu /proc/stat | awk '{print $1","$2","$3","$4","$5","$6","$7","$8","$9","$10","$11";"}' | tr -d '\n')
POST="$POST{cpu_info}$cpu_info{/cpu_info}"
sleep 1s
cpu_info_current=$(grep -i cpu /proc/stat | awk '{print $1","$2","$3","$4","$5","$6","$7","$8","$9","$10","$11";"}' | tr -d '\n')
POST="$POST{cpu_info_current}$cpu_info_current{/cpu_info_current}"

# Disks
disks=$(df -P -T -B 1k | grep '^/' | awk '{print $1","$2","$3","$4","$5","$6","$7";"}' | tr -d '\n')
POST="$POST{disks}$disks{/disks}"

# Disk usage
disks_inodes=$(df -P -i | grep '^/' | awk '{print $1","$2","$3","$4","$5","$6";"}' | tr -d '\n')
POST="$POST{disks_inodes}$disks_inodes{/disks_inodes}"

# File descriptors
file_descriptors=$(cat /proc/sys/fs/file-nr | awk '{print $1","$2","$3}')
POST="$POST{file_descriptors}$file_descriptors{/file_descriptors}"

# RAM Total
ram_total=$(cat /proc/meminfo | grep ^MemTotal: | awk '{print $2}')
POST="$POST{ram_total}$ram_total{/ram_total}"

# RAM Free
ram_free=$(cat /proc/meminfo | grep ^MemFree: | awk '{print $2}')
POST="$POST{ram_free}$ram_free{/ram_free}"

# RAM Caches
ram_caches=$(cat /proc/meminfo | grep ^Cached: | awk '{print $2}')
POST="$POST{ram_caches}$ram_caches{/ram_caches}"

# RAM Buffers
ram_buffers=$(cat /proc/meminfo | grep ^Buffers: | awk '{print $2}')
POST="$POST{ram_buffers}$ram_buffers{/ram_buffers}"

# RAM USAGE
ram_usage=$(($ram_total-($ram_free+$ram_caches+$ram_buffers)))
POST="$POST{ram_usage}$ram_usage{/ram_usage}"

# SWAP Total
swap_total=$(cat /proc/meminfo | grep ^SwapTotal: | awk '{print $2}')
POST="$POST{swap_total}$swap_total{/swap_total}"

# SWAP Free
swap_free=$(cat /proc/meminfo | grep ^SwapFree: | awk '{print $2}')
POST="$POST{swap_free}$swap_free{/swap_free}"

# SWAP Usage
swap_usage=$(($swap_total-$swap_free))
POST="$POST{swap_usage}$swap_usage{/swap_usage}"

# Default Interface
default_interface=$(defaultInterface)
POST="$POST{default_interface}$default_interface{/default_interface}"

# All Interfaces
all_interfaces=$(tail -n +3 /proc/net/dev | tr ":" " " | awk '{print $1","$2","$10","$3","$11";"}' | tr -d ':' | tr -d '\n')
POST="$POST{all_interfaces}$all_interfaces{/all_interfaces}"
sleep 1s
all_interfaces_current=$(tail -n +3 /proc/net/dev | tr ":" " " | awk '{print $1","$2","$10","$3","$11";"}' | tr -d ':' | tr -d '\n')
POST="$POST{all_interfaces_current}$all_interfaces_current{/all_interfaces_current}"


# IPv4 Addresses
ipv4_addresses=$(ip -f inet -o addr show | awk '{split($4,a,"/"); print $2","a[1]";"}' | tr -d '\n')
POST="$POST{ipv4_addresses}$ipv4_addresses{/ipv4_addresses}"

# IPv6 Addresses
ipv6_addresses=$(ip -f inet6 -o addr show | awk '{split($4,a,"/"); print $2","a[1]";"}' | tr -d '\n')
POST="$POST{ipv6_addresses}$ipv6_addresses{/ipv6_addresses}"

# Active Connections
active_connections=$(activeConnections)
POST="$POST{active_connections}$active_connections{/active_connections}"

# Ping Latency
ping_latency=$(pingLatency)
POST="$POST{ping_latency}$ping_latency{/ping_latency}"

# SSH Sessions
ssh_sessions=$(who | wc -l)
POST="$POST{ssh_sessions}$ssh_sessions{/ssh_sessions}"

# Uptime
uptime=$(cat /proc/uptime | awk '{print $1}')
POST="$POST{uptime}$uptime{/uptime}"

# Processes
processes=$(ps -e -o pid,ppid,rss,vsz,uname,pmem,pcpu,comm,cmd --sort=-pcpu,-pmem | awk '{print $1","$2","$3","$4","$5","$6","$7","$8","$9";"}' | tr -d '\n')
POST="$POST{processes}$processes{/processes}"



# Upload data

# -m max-time in seconds
# -k insecure
# -s silent
# -d data


echo "data=$POST" | curl -m 50 -k -s -d @- "$GATEWAY"
