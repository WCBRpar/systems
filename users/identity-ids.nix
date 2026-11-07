# Fonte única para os IDs POSIX comuns entre NixOS e o futuro login via Kanidm.
# No Kanidm, gidNumber de uma pessoa representa simultaneamente UID e GID privado.
{
  persons = {
    wjjunyor = {
      uid = 1000;
      gidNumber = 1000;
    };
    caroles = {
      uid = 2000;
      gidNumber = 2000;
    };
  };

  groups = {
    # IDs reservados e verificados livres nos três servidores em 2026-11-07.
    admins = 100010;
    unixUsers = 100020;
  };
}
