#!/usr/bin/env bash
# -- Command to set profiles for specific server sizes
# -- Usage: gptunemysql (small|medium|large)

# -- Thread Pools
# Use pool-of-threads because https://mariadb.com/kb/en/thread-pool-in-mariadb/
# gp stack mysql -thread-handling pool-of-threads

# -- Thread Pool Size
# thread_pool_size = Number of CPU's
# gp stack mysql -thread-pool-size 4

# -- Thread Pools +
# The rest of the thread_pool_* options are fine as default for now.

# -- Innodb
# innodb_flush_method=O_DIRECT