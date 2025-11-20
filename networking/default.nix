{ config, ... }:

let

  getHost = import ./hosts.nix;

in

{
  # Configuração de rede
  networking = {
    
    hostId = getHost.hostId;
    hostName = getHost.hostName;

    domain = "wcbrpar.com";
    nameservers = [ "84.200.69.80" "84.200.70.40" "1.1.1.1" "8.8.8.8" ]; # CloudFlare / DNS Watch

    resolvconf = {
    };

    interfaces = {
      ztc25hlssg = {
        name = "ztr1s0";
      };
    };

    # Configurações de firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [ 80 443 ]; # HTTP and HTTPS
      trustedInterfaces = [ "venet0" "ztc25hlssg" ];
      extraCommands = ''
      '';
    };

    # Hosts da rede
    extraHosts = ''
      127.0.0.1       localhost
      172.16.129.0    nas.wcbrpar.com
      192.168.13.10   galactica.wcbrpar.com
      192.168.13.20   pegasus.wcbrpar.com
      192.168.13.130  yashuman.wcbrpar.com
    '';
  };

  services = {

    # mDNS Avahi
    avahi = {
      enable = true;
      allowInterfaces = [ "ztc25hlssg" ];
      nssmdns4 = true;
      publish = {
        addresses = true;
        domain = true;
        enable = true;
        userServices = true;
        workstation = true;
      };
    };

    openssh = {
      enable = true;
      openFirewall = true;     # SSH accessible on all interfaces
      allowSFTP = true;
      settings = {
        # PermitRootLogin = "prohibit-password";
        # DenyUsers = [ "root" ];
        AllowUsers = [ "wjjunyor" ];
	# UsePAM = false;
        PasswordAuthentication = true;
	# PubKeyAuthentication = true;
      };
    };

    # ZEROTIER
    zerotierone = {
      enable = true;
      joinNetworks = [
        "abfd31bd47447701" # vpn                (PRIVATE)
      ];
    };

  };

  # OpenSSH
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };


  #  Habilita Builds Remotas via SSH
  nix.settings.trusted-users = ["root" "wjjunyor"];

}
