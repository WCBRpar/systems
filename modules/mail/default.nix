{ config, pkgs, ... }: 

{

  imports = [
    (builtins.fetchTarball {
      # Pick a release version you are interested in and set its hash, e.g.
      url = "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/nixos-24.11/nixos-mailserver-nixos-24.11.tar.gz";
      # To get the sha256 of the nixos-mailserver tarball, we can use the nix-prefetch-url command:
      # release="nixos-23.05"; nix-prefetch-url "https://gitlab.com/simple-nixos-mailserver/nixos-mailserver/-/archive/${release}/nixos-mailserver-${release}.tar.gz" --unpack
      sha256 = "05k4nj2cqz1c5zgqa0c6b8sp3807ps385qca74fgs6cdc415y3qw";
    })

    # calDAV e AntiSpam
    ./agenda.nix
    ./antispam.nix
  ];

  mailserver = {
    enable = true;
    fqdn = "mail.wcbrpar.com";
    domains = [ "wcbrpar.com" "redcom.digital" "ẅalcor.com.br" "wqueiroz.adv.br" ];

    # A list of all login accounts. To create the password hashes, use
    # nix-shell -p mkpasswd --run 'mkpasswd -sm bcrypt'
    # loginAccounts = {
    #   "walter@wcbrpar.com" = {
    #     hashedPasswordFile = config.age.secrets.default.path;
    #     aliases = ["postmaster@wcbrpar.com"];
    #   };
    
    ldap = {
      enable = true;
      uris = [ "ldaps://ldap.wcbrpar.com" ];

      bind = { 
        dn = "cn=mail,ou=accounts,dc=example,dc=com";
	passwordFile = config.age.secrets.default.path;
      };
      searchBase = "cn=mail,ou=accounts,dc=example,dc=com";
    };

    # Use Let's Encrypt certificates. Note that this needs to set up a stripped
    # down nginx and opens port 80.
    certificateScheme = "acme-nginx";
  };

  # services.opendkim = {             # Corrigir no dkim do SNM o diretório 
  #   enable = true;                  # dos arquivos de /var/dkim para /var/lib/dkim... se 
  #   domains = "csl:mail.wcbrpar.com,wcbrpar.com,redcom.digital,walcor.com.br,wqueiroz.adv.br";
  # };

}

