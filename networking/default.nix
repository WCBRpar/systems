{ ... }:

let
  privateZeroTierInterfaces = [
  "zt-wan01" #WCBRpar VPN
  ];
  
in

{

  # Configuração de rede
  networking = {
    hostId = "8bf0dda5"; # cut -c-8 </proc/sys/kernel/random/uuid
    hostName = "galactica"; # Define your hostname.
    domain = "wcbrpar.com";
    nameservers = [ "84.200.69.80" "84.200.70.40" ]; # CloudFlare / DNS Watch
    firewall = {
      enable = true;
      allowedTCPPorts = [ 80 443 ]; # SSH, HTTP and HTTPS
      trustedInterfaces = [ "venet0" ];
    };

    # Hosts da rede
    extraHosts = ''
      127.0.0.1       localhost
      192.168.13.10   galactica.wcbrpar.com
      192.168.13.20   pegasus.wcbrpar.com
    '';
  };

  # mDNS
  services.avahi.enable = true;
  services.avahi.allowInterfaces = privateZeroTierInterfaces;
  services.avahi.nssmdns4 = true;
  services.avahi.publish.addresses = true;
  services.avahi.publish.domain = true;
  services.avahi.publish.enable = true;
  services.avahi.publish.userServices = true;
  services.avahi.publish.workstation = true;

  # Open SSH
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
      DenyUsers = [ "root"];
      AllowUsers = [ "wjjunyor" ];
      PasswordAuthentication = true;
    };
  };

  # ZEROTIER
  # services.zerotierone.enable = true;
  # services.zerotierone.joinNetworks = [
  # "abfd31bd47447701"                        #   WCBRpar PRIVATE
  # ];


}
