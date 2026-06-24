import sys
import os
import subprocess
import argparse

class CSFAirgapValve:
    def __init__(self, univac_ip: str, aviation_ip: str):
        self.univac_ip = univac_ip
        self.aviation_ip = aviation_ip

    def isolate_univac(self) -> bool:
        if not self.univac_ip:
            return False
        subprocess.run(["csf", "-d", self.univac_ip, "UNIVAC_AIRGAP_LOCKED"])
        subprocess.run(["csf", "-r"])
        return True

    def authorize_univac(self) -> bool:
        if not self.univac_ip:
            return False
        subprocess.run(["csf", "-ar", self.univac_ip])
        subprocess.run(["csf", "-a", self.univac_ip, "UNIVAC_UPLINK_AUTHORIZED"])
        subprocess.run(["csf", "-r"])
        return True

if __name__ == "__main__":
    # Setup argparse properly
    parser = argparse.ArgumentParser(description="CSF Airgap Valve")
    parser.add_argument("--univac", required=True, help="UNIVAC IP Address")
    parser.add_argument("--aviation", required=True, help="Aviation IP Address")
    parser.add_argument("--action", choices=["isolate", "authorize"], required=True)
    args = parser.parse_args()

    # Fork logic to instantly return control to the LFD daemon
    if os.fork() != 0:
        sys.exit(0) 

    # FIXED: Actually execute the class logic in the child process
    valve = CSFAirgapValve(univac_ip=args.univac, aviation_ip=args.aviation)
    
    if args.action == "isolate":
        valve.isolate_univac()
    elif args.action == "authorize":
        valve.authorize_univac()
