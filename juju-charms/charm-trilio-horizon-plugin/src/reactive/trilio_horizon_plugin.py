import os
import netaddr
from charms.reactive import (
    when,
    when_not,
    set_flag,
    hook,
    remove_state,
    set_state,
)
from charmhelpers.core.hookenv import (
    status_set,
    config,
    log,
)


def validate_ip(ip):
    """Validate TrilioVault_IP provided by the user
    TrilioVault_IP should not be blank
    TrilioVault_IP should have a valid IP address and reachable
    """
    if ip.strip():
        # Not blank
        if netaddr.valid_ipv4(ip):
            # Valid IP address, check if it's reachable
            ip_re = os.system("ping -c 1 " + ip)
            return ip_re
        else:
            # Invalid IP address
            return 1
    else:
        # Blank
        return 1


def install_plugin(ip, ver):
    """Install Horizon plugin and workloadmgrclient packages
    from TVAULT_IPADDRESS provided by the user
    """
    cmd = "/usr/bin/pip install --no-deps http://" + ip + \
        ":8081/packages/python-workloadmgrclient-" + ver + " > /dev/null 2>&1"
    wm_ret = os.system(cmd)

    if wm_ret:
        # workloadmgrclient package install failed
        log("TrilioVault WorkloadMgrClient package installation failed")
        return wm_ret
    else:
        log("TrilioVault WorkloadMgrClient package installation passed")

    cmd = "/usr/bin/pip install --no-deps http://" + ip + \
        ":8081/packages/tvault-horizon-plugin-" + ver + " > /dev/null 2>&1"
    hp_ret = os.system(cmd)

    if hp_ret:
        # Horixon Plugin package install failed
        log("TrilioVault Horizon Plugin package installation failed")
        return hp_ret
    else:
        log("TrilioVault Horizon Plugin package installation passed")

    # Start the application
    status_set('maintenance', 'Starting...')
    cmd = "service apache2 restart"
    os.system(cmd)

    return 0


def uninstall_plugin():
    # Uninstall Horizon plugin and workloadmgrclient packages
    cmd = "/usr/bin/pip uninstall python-workloadmgrclient -y"
    wm_ret = os.system(cmd)

    if wm_ret:
        # workloadmgrclient package uninstall failed
        log("TrilioVault WorkloadMgrClient package un-installation failed")
        return wm_ret
    else:
        log("TrilioVault WorkloadMgrClient package uninstalled successfully")

    cmd = "/usr/bin/pip uninstall tvault-horizon-plugin -y"
    hp_ret = os.system(cmd)

    if hp_ret:
        # Horixon Plugin package uninstall failed
        log("TrilioVault Horizon Plugin package un-installation failed")
        return hp_ret
    else:
        log("TrilioVault Horizon Plugin package uninstalled successfully")

    # Re-start the Webserver
    cmd = "service apache2 restart"
    os.system(cmd)

    return 0


@when_not('trilio-horizon-plugin.installed')
def install_trilio_horizon_plugin():

    status_set('maintenance', 'Installing...')

    # Push /usr/bin onto the start of $PATH from the hander for the specific
    # subprocess call for the install script.
    # This will make pip to be called from host install rather than virtualenv.

    # Read config parameters TrilioVault version, TrilioVault IP
    tv_version = config('TrilioVault_version')
    tv_ip = config('TrilioVault_IP')

    # Validate TrilioVault_IP
    validate_op = validate_ip(tv_ip)

    if validate_op:
        # IP address is invalid
        # Set status as blocked and return
        status_set(
            'blocked',
            'Invalid IP address, please provide correct IP address')
        return 1

    # Proceed as TrilioVault_IP Address is valid
    # Call install handler to install the packages
    inst_ret = install_plugin(tv_ip, tv_version)

    if not inst_ret:
        # Install was successful
        status_set('active', 'Ready...')

    # Add the flag "installed" since it's done
    set_flag('trilio-horizon-plugin.installed')


@hook('stop')
def stop_handler():

    # Set the user defined "stopping" state when this hook event occurs.
    set_state('trilio-horizon-plugin.stopping')


@when('trilio-horizon-plugin.stopping')
def stop_trilio_horizon_plugin():

    status_set('maintenance', 'Stopping...')

    # Call the script to stop and uninstll TrilioVault Horizon Plugin
    uninst_ret = uninstall_plugin()

    if not uninst_ret:
        # Uninstall was successful
        # Remove the state "stopping" since it's done
        remove_state('trilio-horizon-plugin.stopping')
