{ ... }:

let
  privateZeroTierInterfaces = [
    "zt-wan01" # WCBRpar VPN
  ];
in
{
  # Configuração de rede
  networking = {
    # hostId = "13960a97"; # Galactica            # cut -c-8 < /proc/sys/kernel/random/uuid    
    hostId = "8bf0dda5"; # Pegasus
    # hostname = "galactica";
    hostName = "pegasus";

    domain = "wcbrpar.com";
    nameservers = [ "84.200.69.80" "84.200.70.40" ]; # CloudFlare / DNS Watch

    # Configurações de firewall
    firewall = {
      enable = true;
      allowedTCPPorts = [ 80 443 ]; # HTTP and HTTPS
      trustedInterfaces = [ "venet0" ];
    };

    # Hosts da rede
    extraHosts = ''
      127.0.0.1       localhost
      192.168.13.10   galactica.wcbrpar.com
      192.168.13.20   pegasus.wcbrpar.com
    '';

  };

  # mDNS (Avahi)
  services.avahi = {
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

  # OpenSSH
  programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = true;     # SSH accessible on all interfaces
    allowSFTP = true;
    settings = {
      # PermitRootLogin = "prohibit-password";
      DenyUsers = [ "root" ];
      AllowUsers = [ "wjjunyor" ];
      PasswordAuthentication = true;
    };
  };

  #  Habilita Builds Remotas via SSH
  nix.settings.trusted-users = ["root" "wjjunyor"];

  # ZEROTIER (comentado, mas mantido para referência)
  # services.zerotierone.enable = true;
  # services.zerotierone.joinNetworks = [
  #   "abfd31bd47447701" # WCBRpar PRIVATE
  # ];
}
