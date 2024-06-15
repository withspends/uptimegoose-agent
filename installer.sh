#!/bin/bash
#
# UptimeGoose Agent Installer
# @version		1.0.0
#
# MIT License
# 
# Copyright (c) 2024 Spends Software Ltd
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Set environment
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Prepare output
echo -e "|\n|   UptimeGoose Installer\n|   =====================\n|"

# Root required
if [ $(id -u) != "0" ]; then
	echo -e "|   Error: You need to be root to install the UptimeGoose agent\n|"
	echo -e "|          The agent itself will NOT be running as root but instead under its own non-privileged user\n|"
	exit 1
fi

# Parameters required
if [ $# -lt 1 ]; then
	echo -e "|   Usage: bash $0 'token'\n|"
	exit 1
fi

# Check if crontab is installed
if ! command -v crontab &> /dev/null; then
	# Confirm crontab installation
	echo "|" && read -p "|   Crontab is required and could not be found. Do you want to install it? [Y/n] " input_variable_install

	# Attempt to install crontab
	if [ -z "$input_variable_install" ] || [[ "$input_variable_install" =~ ^[Yy]$ ]]; then
		if command -v apt-get &> /dev/null; then
			echo -e "|\n|   Notice: Installing required package 'cron' via 'apt-get'"
		    apt-get update -y
		    apt-get install -y cron
		elif command -v yum &> /dev/null; then
			echo -e "|\n|   Notice: Installing required package 'cronie' via 'yum'"
		    yum install -y cronie
		    
		    if ! command -v crontab &> /dev/null; then
		    	echo -e "|\n|   Notice: Installing required package 'vixie-cron' via 'yum'"
		    	yum install -y vixie-cron
		    fi
		elif command -v pacman &> /dev/null; then
			echo -e "|\n|   Notice: Installing required package 'cronie' via 'pacman'"
		    pacman -Syu --noconfirm cronie
		fi
	fi
	
	if ! command -v crontab &> /dev/null; then
	    # Show error
	    echo -e "|\n|   Error: Crontab is required and could not be installed\n|"
	    exit 1
	fi	
fi

# Check if cron is running
if ! pgrep -x "cron" > /dev/null; then
	# Confirm cron service
	echo "|" && read -p "|   Cron is available but not running. Do you want to start it? [Y/n] " input_variable_service

	# Attempt to start cron
	if [ -z "$input_variable_service" ] || [[ "$input_variable_service" =~ ^[Yy]$ ]]; then
		if command -v apt-get &> /dev/null; then
			echo -e "|\n|   Notice: Starting 'cron' via 'service'"
			service cron start
		elif command -v yum &> /dev/null; then
			echo -e "|\n|   Notice: Starting 'crond' via 'service'"
			systemctl enable crond
			systemctl start crond
		elif command -v pacman &> /dev/null; then
			echo -e "|\n|   Notice: Starting 'cronie' via 'systemctl'"
		    systemctl enable cronie
		    systemctl start cronie
		fi
	fi
	
	# Check if cron was started
	if ! pgrep -x "cron" > /dev/null; then
		# Show error
		echo -e "|\n|   Error: Cron is available but could not be started\n|"
		exit 1
	fi
fi

# Attempt to delete previous agent
if [ -f /etc/uptimegoose/agent.sh ]; then
	# Remove agent dir
	rm -rf /etc/uptimegoose

	# Remove cron entry and user
	if id -u uptimegoose &> /dev/null; then
		(crontab -u uptimegoose -l | grep -v "/etc/uptimegoose/agent.sh") | crontab -u uptimegoose - && userdel uptimegoose
	else
		(crontab -u root -l | grep -v "/etc/uptimegoose/agent.sh") | crontab -u root -
	fi
fi

# Create agent dir
mkdir -p /etc/uptimegoose

# Download agent
echo -e "|   Downloading agent.sh to /etc/uptimegoose\n|\n|   + $(wget -nv -o /dev/stdout -O /etc/uptimegoose/agent.sh --no-check-certificate https://raw.githubusercontent.com/withspends/uptimegoose-agent/main/agent.sh)"

if [ -f /etc/uptimegoose/agent.sh ]; then
	# Create auth file
	echo "$1" > /etc/uptimegoose/auth.log
	
	# Create user
	useradd -r -d /etc/uptimegoose -s /usr/sbin/nologin uptimegoose
	
	# Modify user permissions
	chown -R uptimegoose:uptimegoose /etc/uptimegoose && chmod -R 700 /etc/uptimegoose
	
	# Modify ping permissions
	chmod +s "$(command -v ping)"

	# Configure cron
	(crontab -u uptimegoose -l 2>/dev/null; echo "*/3 * * * * bash /etc/uptimegoose/agent.sh > /etc/uptimegoose/cron.log 2>&1") | crontab -u uptimegoose -
	
	# Show success
	echo -e "|\n|   Success: The UptimeGoose agent has been installed\n|"
	
	# Attempt to delete installation script
	if [ -f "$0" ]; then
		rm -f "$0"
	fi
else
	# Show error
	echo -e "|\n|   Error: The UptimeGoose agent could not be installed\n|"
fi