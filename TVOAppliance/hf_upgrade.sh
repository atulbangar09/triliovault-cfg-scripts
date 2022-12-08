#!/bin/bash 

BASE_DIR="$(pwd)"
PYTHON_VERSION="Python 3.8.12"

#function to display usage...
function usage()
{
  echo "Usage: ./hf_upgrade.sh 	[ -h | --help ]
				[ -d | --downloadonly ]
                               	[ -i | --installonly ] 
                               	[ -a | --all   ]"
  exit 2
}


#function to download the package and extract...
function download_package()
{
	#define file id and filename which we want to download.
	fileid=16JM1Z1jZvISwmo0Bqnj0wJSUu2C1ZJ7G
	outfile="offline_pkgs.tar.gz"

	echo "Downloading $outfile for Yoga release"

	#run the wget command to download the package.
	wget_command=`wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=$fileid' -O- | sed -rn 's/.confirm=([0-9A-Za-z_]+)./\1\n/p')&id=$fileid" -O $outfile && rm -rf /tmp/cookies.txt`

}

function check_package_status()
{
        all_pkgs=`ls -1`

	# iterate through all packages to check installation status.
        for pkg_name in $all_pkgs
        do
                if [[ $pkg_name = *"rpm"* ]]; then
                        #remove last 4 chars of (.rpm)
                        total_len="${#pkg_name}"
                        rpm_pkg_info="${pkg_name:0:$total_len-4}"

                        #check result for this package
                        rpm_result=`rpm -qa | grep $rpm_pkg_info`
                        result=$?
                        if [[ $result == 1 ]]; then
                                echo "Package $rpm_pkg_info not found on the system."
				# perform yum command to install package.
				install_cmd=`yum -y install $rpm_pkg_info.rpm`	
			else
				echo "Package $rpm_pkg_info.rpm present on the system."
                        fi
                fi
        done
}

#function to install the package on the system...
function install_package()
{

	#it is expected that package is available in current directory.
	outfile="$BASE_DIR/offline_pkgs.tar.gz"
	if [[ -f $outfile ]]
	then
		echo "$outfile present. we can continue with the installation."

		echo "Extracting $outfile now"
		#now the package is downloaded. Extract the package.
		extract_packages=`tar -xzf $outfile`
	
	else
		echo "$outfile is not present. Cannot proceed with the installation. Exiting."
		exit 2
	fi
	
	echo "Installing $outfile for Yoga release"

	#make sure to be in base directory for installation.
	cd $BASE_DIR

	#extract Python-3.8.12.tgz - first check if python 3.8.12 version is availble or not.
	python_version=`python3 --version`
	if [ "$python_version" == "$PYTHON_VERSION" ]; then
	  echo "Python 3.8.12 package is already installed. We can skip Python package installation."

	else
	  echo "Python 3.8.12 package is missing. We need to install Python package."

	  #extract offline_dist_pkgs.tar.gz file to install dependancy packages first.
	  extract_offline_dist_pkg=`tar -xzf offline_dist_pkgs.tar.gz`
	  cd offline_dist_pkgs*/
	  #check if the packages are already installed or not. call function check_package_status() 
	  check_package_status

	  #move to base dir again
	  cd $BASE_DIR

	  #Install python 3.8.12 package on the TVO appliance.
	  extract_python_pkg=`tar -xf Python-3.8.12.tgz`
	  cd Python-3.8.12*/
          config_cmd=`./configure --enable-optimizations`
          make_cmd=`sudo make altinstall`

	fi

	#move to base dir again
	cd $BASE_DIR

	#now move existing myansible enviornment
	date=`date '+%Y-%m-%d-%H:%M:%S'`
	mv /home/stack/myansible /home/stack/myansible_old_$date
	mkdir -p /home/stack/myansible 

	#extract the package at the / directory.
	extract_myansible_pkg=`tar -xzf myansible_py38.tar.gz -C /`

	#set the default python3
	update_python_cmd=`update-alternatives --install /usr/bin/python3 python3 /usr/local/bin/python3.8 0`

	#restart the services post install
	service_restart_cmd=`systemctl restart tvault-config wlm-workloads wlm-api wlm-cron wlm-workloads`

	#restart s3 related services.
	service_restart_s3_cmd=`systemctl restart tvault-object-store`
	
}

########  Start of the script.  ########

CMDLINE_ARGUMENTS=$(getopt -o hdia --long help,downloadonly,installonly,all -- "$@")
CMD_OUTPUT=$?
if [ "$CMD_OUTPUT" != "0" ]; then
  usage
fi

eval set -- "$CMDLINE_ARGUMENTS"

echo "TVO Upgrade for Yoga release from previous 4.2GA/4.2HF"

#command line arguments.
if [ $# -le 1 ]; then
  echo "Invalid number of arguments"
  usage
fi


if [ $# -gt 0 ]; then
  case "$1" in
    -h|--help) usage; exit;;
    -d|--downloadonly) download_package ;;
    -i|--installonly)  install_package ;;
    -a|--all) download_package; install_package ;;
  esac
  shift
fi

