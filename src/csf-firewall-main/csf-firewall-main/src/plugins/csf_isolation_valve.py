import subprocess

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

    def isolate_aviation(self) -> bool:
        if not self.aviation_ip:
            return False
        subprocess.run(["csf", "-d", self.aviation_ip, "AVIATION_AIRGAP_LOCKED"])
        subprocess.run(["csf", "-r"])
        return True

    def authorize_aviation(self) -> bool:
        if not self.aviation_ip:
            return False
        subprocess.run(["csf", "-ar", self.aviation_ip])
        subprocess.run(["csf", "-a", self.aviation_ip, "AVIATION_UPLINK_AUTHORIZED"])
        subprocess.run(["csf", "-r"])
        return True
