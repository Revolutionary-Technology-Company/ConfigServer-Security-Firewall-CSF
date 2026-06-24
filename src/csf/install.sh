#!/bin/sh
# #
#   @app                ConfigServer Security & Firewall (CSF)
#                       Login Failure Daemon (LFD)
#   @website            https://configserver.dev
#   @docs               https://docs.configserver.dev
#   @download           https://download.configserver.dev
#   @repo               https://github.com/Aetherinox/csf-firewall
#   @copyright          Copyright (C) 2025-2026 Aetherinox
#                       Copyright (C) 2006-2025 Jonathan Michaelson
#                       Copyright (C) 2006-2025 Way to the Web Ltd.
#   @license            GPLv3
#   @updated            02.12.2026
#   
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or (at
#   your option) any later version.
#   
#   This program is distributed in the hope that it will be useful, but
#   WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#   General Public License for more details.
#   
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, see <https://www.gnu.org/licenses>.
# #

# #
#   @script             ConfigServer Security & Firewall Installer
#   @desc               determines the users distro and (if any) control panel, launches correct installer sub-script
#   
#   @usage              Normal install          sh install.sh
#                       Dryrun install          sh install.sh --dryrun
# #

# Add to install.sh
mkdir -p /var/log/csf_ram
mount -t tmpfs -o size=256M tmpfs /var/log/csf_ram
# Update your logging daemons to write to /var/log/csf_ram/ instead of /var/log/apache2/

# Append to file distribution block inside install.sh
echo "[*] Provisioning commercial licensing systems..."

# Move the update orchestrator and licensing profiles to runtime roots
cp bin/rt-csf-update.sh /usr/local/csf/bin/rt-csf-update.sh
cp licensing_policy.md /usr/local/csf/licensing_policy.md
chmod +x /usr/local/csf/bin/rt-csf-update.sh

# Establish standard symbolic path redirection for system updates
rm -f /usr/sbin/rt-csf-update
ln -s /usr/local/csf/bin/rt-csf-update.sh /usr/sbin/rt-csf-update

echo "    > Connected update client to primary system sbin routing tree."

# ==============================================================================
# REVOLUTIONARY TECHNOLOGY - ENTERPRISE ENGINE INTEGRATION
# ==============================================================================
echo "[+] Initializing Revolutionary Technology Deployment Pipeline..."

# 1. Establish Custom Directories
mkdir -p /usr/local/csf/bin
mkdir -p /usr/local/csf/plugins
mkdir -p /etc/csf/xdp
mkdir -p /etc/csf/modsec

# 2. Deploy Binaries, Plugins, and Source Files
echo "    > Deploying execution binaries and Python plugins..."
cp bin/* /usr/local/csf/bin/
cp plugins/* /usr/local/csf/plugins/
cp xdp/* /etc/csf/xdp/
cp modsec/* /etc/csf/modsec/
cp rt_uninstall_engine.sh /usr/local/csf/bin/

# Hook the Stateless Engine into CSF's native post-restart trigger
cp csfpost.sh /etc/csf/csfpost.sh

# Apply executable permissions globally to the deployment
chmod +x /usr/local/csf/bin/*.sh
chmod +x /usr/local/csf/bin/*.pl
chmod +x /usr/local/csf/plugins/*.py
chmod +x /etc/csf/csfpost.sh

# 3. Phase 1: Compile & Sign Kernel Modules (Secure Boot/Xtables)
echo "    > Phase 1: Building and Signing xtables-addons..."
/usr/local/csf/bin/rt-install-modules.sh

# 4. Phase 2: Inject U32 and SYN Hardening
echo "    > Phase 2: Injecting U32 DDoS Mitigations..."
/usr/local/csf/bin/ddos_mitigation.sh $(ip route show default | awk '/default/ {print $5}' | head -n1)

# 5. Phase 3: Hardware Acceleration & Dynamic Tuning
echo "    > Phase 3: Activating Responsive Resource Allocation Engine..."
/usr/local/csf/bin/csf-autotune.sh

# 6. Phase 4: Compile & Attach eBPF/XDP Shield
echo "    > Phase 4: Compiling XDP Hardware Offload..."
/usr/local/csf/bin/csf_bpf_loader.sh

# 7. Deploy Threat Intelligence Cron Jobs
echo "    > Deploying automated intelligence pollers..."
ln -s /usr/local/csf/bin/rt-block-reporter.sh /etc/cron.daily/rt-block-reporter
ln -s /usr/local/csf/bin/rt-google-ip-updater.pl /etc/cron.weekly/rt-google-ip-updater

# 8. ModSecurity 3.x LFD Backwards Compatibility Daemon
echo "    > Scanning for ModSecurity version protocols..."
MODSEC3_PATH="/var/log/apache2/modsec_audit.log"
if [ -f "$MODSEC3_PATH" ] && grep -q '{' "$MODSEC3_PATH"; then
    echo "      [ModSec3 Detected] Re-routing logs and starting converter daemon..."
    sed -i 's|^MODSEC_LOG = .*|MODSEC_LOG = "/var/log/apache2/modsec_legacy_lfd.log"|' "/etc/csf/csf.conf"
    
    cp /usr/local/csf/bin/modsec3_converter.pl /usr/local/bin/
    cat << 'EOF' > /etc/systemd/system/modsec3-converter.service
[Unit]
Description=RT ModSec3 to LFD Log Converter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/modsec3_converter.pl
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable --now modsec3-converter.service >/dev/null 2>&1
fi

# 9. Final Structural Reload
echo "[+] Revolutionary Technology Engines Online. Executing final firewall reload..."
csf -r >/dev/null 2>&1

echo "==================================================================="
echo " INSTALLATION COMPLETE"
echo " Note: If Secure Boot is enforced, a reboot is required to enroll"
echo " the MOK keys for the xtables-addons stateless driver pack."
echo " Run: /usr/local/csf/bin/csf-firmware-check.sh to verify NIC status."
echo "==================================================================="

echo "[*] Scanning for ModSecurity version protocols..."

# Target standard WHM ModSec3 audit path
MODSEC3_PATH="/var/log/apache2/modsec_audit.log"
CSF_CONF="/etc/csf/csf.conf"

if [ -f "$MODSEC3_PATH" ] && grep -q '{' "$MODSEC3_PATH"; then
    echo "    > ModSecurity 3.x (JSON) detected."
    
    # 1. Update the log path so LFD watches the flattened output instead of the raw JSON
    sed -i 's|^MODSEC_LOG = .*|MODSEC_LOG = "/var/log/apache2/modsec_legacy_lfd.log"|' "$CSF_CONF"
    
    # 2. Deploy the converter service
    cp /usr/local/csf/bin/modsec3_converter.pl /usr/local/bin/
    chmod +x /usr/local/bin/modsec3_converter.pl
    
    cat << 'EOF' > /etc/systemd/system/modsec3-converter.service
[Unit]
Description=RT ModSec3 to LFD Log Converter
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/modsec3_converter.pl
Restart=always

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable modsec3-converter.service
    systemctl start modsec3-converter.service
    
    echo "    > Deployed 'modsec3-converter.service'. LFD backwards compatibility activated."
else
    echo "    > Standard ModSecurity 2.x detected. Native CSF parsing will be used."
fi

# ==============================================================================
# PHASE 7: Deploy Automated Threat Intelligence Pipeline
# ==============================================================================
echo "    > Provisioning Community Defense Reporting Systems..."

# Move the reporter script assets to the secure executable library tree
cp bin/rt-block-reporter.sh /usr/local/csf/bin/rt-block-reporter.sh
chmod +x /usr/local/csf/bin/rt-block-reporter.sh

# Establish an automated link inside the system's hourly cron engine path
rm -f /etc/cron.hourly/rt-block-reporter
ln -s /usr/local/csf/bin/rt-block-reporter.sh /etc/cron.hourly/rt-block-reporter

echo "      [Done] Connected rt-block-reporter.sh to hourly cron orchestrator."

# ==============================================================================
# PHASE 8: Deploy RT Zero Trust Defense (Google Safe Sites Integration)
# ==============================================================================
echo "    > Deploying RT Google Safe Sites 24/7 Poller..."

# Make the poller script executable
chmod +x /usr/local/csf/bin/rt-gsb-poller.sh

# Create the systemd service file
cat << 'EOF' > /etc/systemd/system/rt-gsb-poller.service
[Unit]
Description=RT Google Safe Sites Poller (Zero Trust Defense)
After=network.target csf.service

[Service]
Type=simple
ExecStart=/usr/local/csf/bin/rt-gsb-poller.sh
Restart=on-failure
RestartSec=30

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and start the engine
systemctl daemon-reload
systemctl enable rt-gsb-poller.service >/dev/null 2>&1
systemctl restart rt-gsb-poller.service >/dev/null 2>&1

echo "      [Done] rt-gsb-poller.service is now running in the background."

# #
#	Allow for execution from different relative directories
# #

case $0 in
    /*) script="$0" ;;                       # Absolute path
    *)  script="$(pwd)/$0" ;;                # Relative path
esac

# #
#	Find script directory
# #

script_dir=$(dirname "${script}")

# #
#   Include global
# #

. "${script_dir}/global.sh" ||
{
    echo "    Error: cannot source ${script_dir}/global.sh. Aborting." >&2
    exit 1
}

# #
#    Change working directory
# #

cd "${script_dir}" || exit 1

# #
#   Define › Args
# #

argDryrun="false"				# runs the logic but doesn't actually install; no changes
argDetect="false"				# returns the installer name + desc that would have ran, but exits; no changes
argLegacy="false"				# certain actions will work how pre CSF v15.01 did 

# #
#   Func › Usage Menu
# #

opt_usage( )
{
    echo
    printf "  ${bluel}${APP_NAME}${end}\n" 1>&2
    printf "  ${greym}${APP_DESC}${end}\n" 1>&2
    printf "  ${greyd}version:${end} ${greyd}$APP_VERSION${end}\n" 1>&2
    printf "  ${magental}${app_file_this}${end} ${greyd}[ ${greym}--detect${greyd} | ${greym}--dryrun${greyd} |  ${greym}--version${greyd} | ${greym}--help ${greyd}]${end}" 1>&2
    echo
    echo
    printf '   %-5s %-40s\n' "${greyd}Syntax:${end}" "" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "${greyd}Command${end}           " "${magental}${app_file_this}${greyd} [ ${greym}--option ${greyd}[ ${yellowd}arg${greyd} ]${greyd} ]${end}" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "${greyd}Options${end}           " "${magental}${app_file_this}${greyd} [ ${greym}-h${greyd} | ${greym}--help${greyd} ]${end}" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "    ${greym}-A${end}            " "   ${white}required" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "    ${greym}-A...${end}         " "   ${white}required; multiple can be specified" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "    ${greym}[ -A ]${end}        " "   ${white}optional" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "    ${greym}[ -A... ]${end}     " "   ${white}optional; multiple can be specified" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "    ${greym}{ -A | -B }${end}   " "   ${white}one or the other; do not use both" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "${greyd}Examples${end}          " "${magental}${app_file_this}${end} ${greym}--detect${yellowd} ${end}" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${magental}${app_file_this}${end} ${greym}--dryrun${yellowd} ${end}" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${magental}${app_file_this}${end} ${greym}--version${yellowd} ${end}" 1>&2
    printf '   %-5s %-30s %-40s\n' "    " "${greyd}${end}                  " "${magental}${app_file_this}${end} ${greym}--help${greyd} | ${greym}-h${greyd} | ${greym}/?${end}" 1>&2
    echo
    printf '   %-5s %-40s\n' "${greyd}Flags:${end}" "" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-D${greyd},${blued}  --detect ${yellowd}${end}                     " "returns installer script that will run; does not install csf ${navy}<default> ${peach}${argDetect:-"disabled"} ${end}" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-d${greyd},${blued}  --dryrun ${yellowd}${end}                     " "simulates installation, does not install csf ${navy}<default> ${peach}${argDryrun:-"disabled"} ${end}" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-v${greyd},${blued}  --version ${yellowd}${end}                    " "current version of this utilty ${navy}<current> ${peach}${APP_VERSION:-"unknown"} ${end}" 1>&2
    printf '   %-5s %-81s %-40s\n' "    " "${blued}-h${greyd},${blued}  --help ${yellowd}${end}                       " "show this help menu ${end}" 1>&2
    echo
    echo
}

# #
#   Args › Parse
# #

while [ "$#" -gt 0 ]; do
    case "$1" in
        -d|--dryrun)
            argDryrun="true"
            ;;
        -D|--detect)
            argDetect="true"
            ;;
        -l|--legacy)
            argLegacy="true"
            ;;
        -v|--ver|--version)
            print
			print "    ${blued}${bold}${APP_NAME}${end} - v${APP_VERSION} "
			print "    ${greenl}${bold}${APP_REPO} "
            print
            exit 1
            ;;
        -h|--help|\?)
            opt_usage
            exit 1
            ;;
        *)
            print
			error "    ❌ Unknown flag ${redl}$1${greym}. Aborting."
            print
			exit 1
			;;
    esac
    shift
done

# #
#   Export
# #

export argDryrun argDetect argLegacy

# #
#	Runs the requested installer
#	
#	@arg 			installerFile				Install script to run
#	@arg 			installerDesc				Brief description for the user
#	@usage			run_installer "install.cpanel.sh" "csf cPanel installer"
# #

run_installer()
{
    installer="$1"
    description="$2"

	# #
	#	Detect; but do not run
	# #

    if [ "${argDetect}" = "true" ]; then
        print
		ok "    Detected Installer: ${greenl}${script_dir}/${installer}${greym} (${description}) "
        print
		exit 0
	fi

	# #
	#	Dryrun; or run chosen installer script
	# #

    if [ "${argDryrun}" = "true" ]; then
		ok "    Dryrun flag specified; skipped installer ${greenl}${script_dir}/${installer}${greym} "
    fi

    print
    print "   ${greyd}# #"
    print "   ${greyd}#  ${bluel}${APP_NAME} › Installer${end}" 1>&2
    print "   ${greyd}#  ${greyd}version:${end} ${greyd}$APP_VERSION${end}" 1>&2
    print "   ${greyd}# #"
    print
    ok "    Starting installer ${greenl}${description}${greym} › ${greenl}${installer}"
    print

    sh "${script_dir}/${installer}" "${installer}" "${description}"
}

echo "Verifying xtables-addons compatibility for nftables translation..."
if modprobe xt_TARPIT 2>/dev/null; then
    echo "  [OK] xt_TARPIT module loaded successfully."
else
    echo "  [WARNING] xt_TARPIT module not found. Advanced drop targets may fail in native mode."
fi

# Ensure the template is copied to the live directory
cp src/csf/nftables.conf /etc/csf/nftables.conf

# #
#   Define which installation script to run
# #

if [ -e "/usr/local/cpanel/version" ]; then
    run_installer "install.cpanel.sh" "cPanel"
elif [ -e "/usr/local/directadmin/directadmin" ]; then
    run_installer "install.directadmin.sh" "DirectAdmin"
elif [ -e "/usr/local/interworx" ]; then
    run_installer "install.interworx.sh" "InterWorx"
elif [ -e "/usr/local/cwpsrv" ]; then
    run_installer "install.cwp.sh" "Control Web Panel (CWP)"
elif [ -e "/usr/local/vesta" ]; then
    run_installer "install.vesta.sh" "VestaCP"
elif [ -e "/usr/local/CyberCP" ]; then
    run_installer "install.cyberpanel.sh" "CyberPanel"
else
    run_installer "install.generic.sh" "Generic"
fi
