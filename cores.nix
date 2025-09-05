{
  available = 32;
  total = rec {
    threads-per-core = 2;
    cores-per-socket = 24;
    sockets = 1;
    physical = cores-per-socket * sockets;
    threads-total = threads-per-core * physical;
  };
}
