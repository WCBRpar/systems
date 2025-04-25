{ ... }:

let
  privateZeroTierInterfaces = [
    "ztr1s0" # vpn
  ];
in

{
  # Configuração de rede
  networking = {
    
    # hostId = "13960a97"; # Galactica            # cut -c-8 < /proc/sys/kernel/random/uuid    
    # hostname = "galactica";
    
    # hostId = "8bf0dda5"; # Pegasus
    # hostName = "pegasus";

    hostId = "e491eb5c";
    hostName = "yashuman";

    domain = "wcbrpar.com";
    nameservers = [ "84.200.69.80" "84.200.70.40" "1.1.1.1" "8.8.8.8" ]; # CloudFlare / DNS Watch

    resolvconf = {
    };

    # Configurações de firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [ 80 443 ]; # HTTP and HTTPS
      trustedInterfaces = [ "venet0" "ztr1s0" "ztc25hlssg" ];
    };

    # Hosts da rede
    extraHosts = ''
      127.0.0.1       localhost
      192.168.13.10   galactica.wcbrpar.com
      192.168.13.20   pegasus.wcbrpar.com
      192.168.13.130  yashuman.wcbrpar.com
    '';

  };

  services = {

    # mDNS Avahi
    avahi = {
      enable = true;
      allowInterfaces = privateZeroTierInterfaces;
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
        PermitRootLogin = "prohibit-password";
        DenyUsers = [ "root" ];
        AllowUsers = [ "wjjunyor" ];
        PasswordAuthentication = true;
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
