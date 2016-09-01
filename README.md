# Bakfile: A Private File Server

This repository permits to build Docker images for a secure rsync server and
related utilities. Users are authenticated using SSH public keys. The goal of
this repository is to make the following tasks easier:

* Setup a secure rsync server for a [LAN](https://en.wikipedia.org/wiki/Local_area_network).
* Upgrade the server or the user list without losing data.
* Upload/download encrypted backups to/from the cloud (using Duplicity).
* Manage encryption keys.
* Sandbox everything inside Linux containers (using Docker Engine and Docker
  Compose).


## 1. Requirements (what you will need)

* A POSIX system (Linux, OS X, Cygwin, Linux Subsystem for Windows…)

* GNU Make

* Docker Engine, version 1.10 or greater

* Docker Compose, version 1.7 or greater

* Enough space in Docker’s workspace (`/var/lib/docker` on Linux) to hold the
  server and its user’s files.

* When upgrading the server or the user list, enough space in the `bak`
  sub-directory of the project directory (this directory) to hold a
  copy of the `home` and `duplicity.cache` volumes. For details, see the
  “2.3. Volumes” section.


## 2. What we have here

### 2.1. Files (what is in the project directory)

* `bak/`: Used for exportation/importation. See the `export` and `import`
   targets of the `Makefile`.

* `src/`: Docker build contexts.

	* `docker-compose.yml`: Docker Compose configuration.

	* `tk.backfile_users/root`: Files copied in the `/root` directory of the
	  image.

		* `rsync-users`: List of the SSH users. All lines must be in the form
		  `{UID}:{userName}`. Example: `1025:somebody`. The UID should be
		  between 1025 and 29999. Empty lines are ignored.

		  **Note:** IDs between 1000 and 1024 are reserved for use by scripts in
		  this project.

		* `ssh-auth-keys/`: The initial SSH authentication keys of the users.
		  For each user, this directory must contain a file with the name of the
		  user and with the content of the wanted `~/.ssh/authorized_keys` file.

	* `tk.bakfile_rsync/sshd_config`: Used by `tk.bakfile_rsync` as the
	  `/etc/ssh/sshd_config` configuration file. If the default
	  `/etc/ssh/sshd_config` file has changed since the version(s) specified in
	  the file, you may need to update some settings.

* `Makefile`: Builds the contexts needed to build the Docker images.

* `compose`: A wrapper around Docker Compose that sets the project name and
  directory. Assumes that the current directory is the root of this project.
  This file is generated by the `Makefile`.


### 2.2. Services

* `users`: Base image for the other images. Creates the `rsync-users`  group and
  the users. Populates the `.ssh` directory (SSH keys) of the users. Any image
  using the data of the file server must inherit of this service (by using
  `FROM tk.bakfile_users`) so UIDs and GIDs will be correctly set.

* `bash`: Same as `users`, but with Bash as the entry point.
  Used internally by the `run-data-shell` target of the `Makefile`.

* `rsync`: An OpenSSH server with rsync. The entry point is the command of the
  SSH daemon.

* `duplicity`: Duplicity installed and set it as the entry point.

* `gpg`: GnuPG 2 installed and set as the entry point.
  Useful to manage the encryption keys for the backups.
  Depends on `duplicity`.

* `tar`: Used internally by the `import` and `export` targets of the `Makefile`.


### 2.3. Volumes

* `home` (`/home`): User’s files, including authentication keys (as usual).

* `duplicity.cache` (`/root/.cache/duplicity`): Duplicity’s cache.

* Anonymous volume for `/root/.gnupg`: Files for GnuPG. Mapped to an host’s
  directory while following the instructions in the “5.2. How to launch a
  Duplicity backup” section.


## 3. Things to consider before the installation

### 3.1. If you do not use `sudo`

If you do not want to use `sudo`, specify `SUDO=` every time you run `make`.
For example, run `make SUDO= something` instead of `make something`.

**Note:** You will need the root privileges for most targets.


### 3.2. Setup a firewall

Before running the rsync/ssh server, you should setup a firewall on the host to
restrict the incoming connections.


#### 3.2.1. How to setup ufw/gufw

**Note:** The “host port” is the port the users will use to connect to your
server.

1. If not already done, enable the firewall.

2. Ensure that incoming connections are denied by default.

3. Add a rule to allow incoming connections to the rsync/ssh port on the host
   (TCP). When possible, you should not use a well-known port for Bakfile
   in order to limit the number of connections from software that look for
   vulnerable servers (this would just fill logs with garbage).

   Note this number, because you will have to specify to the Bakfile’s
   `Makefile` during the installation. You will also need the port number to
   configure the clients.

4. If possible, restrict the rule to connections from a specific
   [subnet](https://en.wikipedia.org/wiki/Subnetwork). This provides an
   additional protection against connections coming from outside your LAN.

5. Add a `LIMIT` rule for the host port (TCP). This will limit the rate of the
   connections that come from a same IP address.

## 4. Installation

### 4.1. How to install/build

1. Fill `src/tk.backfile_users/root/rsync-users` and
   `src/tk.backfile_users/root/ssh-auth-keys/` as explained in the “2.1. Files”
   section.

2. Run `make GNUPG_HOMEDIR=<.gnupg> RSYNC_PORT=<host port> install`,
   replacing `<.gnupg>` and `<host port>` by the appropriate values.
   `<.gnupg>` corresponds to the absolute path to the directory in the host
   where to put GnuPG data (encryption keys). `<host port>` is the port on the
   host that will be used to connect to the server. When possible, you should
   not use well-known ports in order to limit the number of connections from
   software that look for vulnerable servers.

   **Note:** If you get dependency problems, try to use the `upgrade` target
   instead of `install`. This will force the Debian image (on which all the
   Bakfile’s images depend) to be upgraded before rebuilding the Bakfile’s
   images.

   **Note:** If you want to change a value specified to `make … install`, you
   must run `make clean` before invoking `make … install` again.

The last step will also generate a POSIX shell script named `./compose`. This
script is a wrapper around Docker Compose that sets the values of the `-f` and
`-p` options for this project so you do not have to specify them yourself when
you run this script instead of calling Docker Compose directly.

**Note:** The `./compose` script assumes that the project directory is the
current working directory.

**Note:** Never use the `up` subcommand without specifying a service because a
lot of “services” defined in this project are not daemons.

**Note:** To regenerate `./compose` (for example, because you forgot to override
a variable of the `Makefile`), run `make clean && make`.


### 4.2. How to test the SSH configuration

1. Run `make installcheck`.


## 5. Usage and debugging

### 5.1. How to start the rsync/ssh server

1. Run `./compose up -d rsync`.


### 5.2. How to launch a Duplicity backup

In the following instructions, `<.gnupg>` refers to the directory in the host
where to put GnuPG data.

**Note:** Duplicity uses GnuPG to encrypt backups.

1. Ensure that `<.gnupg>` has `root:root` as the ownership and `0700` (“only the
   owner has rights”) as the permissions.

2. If not already done, generate a signing and an encryption key by running
   `./compose run --rm gpg --gen-key`.

   **Note:** If you forget the ID of the generated keys, you may look for them
   by running
   `./compose run --rm gpg --list-keys`.

3. Run `./compose run --rm duplicity <args...>`,
   replacing `<args...>` by the arguments to pass to the `duplicity` command.

   Example:

   ```
   ./compose pause rsync
   ./compose run --rm duplicity \
       --full-if-older-than 1M --sign-key ABCD1234 --encrypt-key DCBA4321 \
       --progress -- /home \
       copy://user@mail.example.com@copy.com/bakfile-home
   ./compose run --rm duplicity remove-all-but-n-full 2 \
       --force --sign-key ABCD1234 --encrypt-key DCBA432 -- \
       copy://user@mail.example.com@copy.com/bakfile-home
   ./compose unpause rsync
   ```


### 5.3. How to open a shell in the `/home` volume

1. Invoke `make run-data-shell`.


## 6. Upgrades and user management


### 6.1. How to upgrade the images (including their dependencies)

Following this procedure will upgrade the Debian image on which the Bakfile’s
images are based, then will rebuild all the Bakfile’s images, while leaving
all volumes (such as `/home`) as-is.

1. Make sure the content of `src/tk.backfile_users/root/rsync-users`,
   `src/tk.backfile_users/root/ssh-auth-keys/` and `compose` is the same as it
   was during the last install/build (the last invocation of `make… install` or
   `make upgrade`). This ensures that the same settings and user list will be
   reapplied during the rebuild.

2. Run `make upgrade`.

### 6.2. How to upgrade the user list

If you want to add or remove users while keeping data held by
`tk.bakfile_data`, do the following:

1. Edit the `src/tk.backfile_users/root/ssh-users` file to reflect the desired
   user list and UIDs. For details, see the “2.1. Files” section.

   **Note:** During the following steps, `tar` will be used to export and
   reimport the `/home` volume. To restore ownership, it will try to match user
   and group names first, and fall back using the saved UID and GID. For more
   information, see documentation of the `--numeric-owner` option of GNU Tar and
   [http://serverfault.com/a/445504](http://serverfault.com/a/445504). This
   means you should not change existing names and IDs. If you do and `tar` does
   not restore ownership correctly, see the “6.3. How to change ownership in
   batch” section bellow.

   **Note:** Whenever possible, you should avoid re-using the names or UIDs of
   the deleted users. Better be safe than sorry. :)

2. Ensure that the `src/tk.backfile_users/root/ssh-auth-keys` directory contains
   the authentication keys of the desired users and does not contain any file
   associated to the users that will be removed. For details, see the “2.1.
   Files” section.

3. Stop (but do not remove yet) Bakfile’s containers by invoking
   `./compose stop`.

4. Run `make export`. This makes a GNU TAR of the volumes at `bak/volumes.tar`.
   Before continuing, you should double-check the archive.

5. Fully uninstall (“purge”) Bakfile. You may use `make purge` to do this.

   **WARNING:** This will delete the `/home` volume. So, again, you should be
   sure that you did the previous step correctly before doing this.

6. Build the images as described in the second step of the “4.1. How to
   install/build” section.

7. Run `make import`. This restores the content of the `home` (`/home`) and
   `duplicity.cache` (`/root/.cache/duplicity`) volumes from the
   `bak/volumes.tar` archive.

8. For each user to remove, delete its “home” directory from `/home` using
   a shell as described in the “5.3. How to open a shell in the `/home` volume”
   section.

9. Check ownership of the imported files  by using the `tk.bakfile_data`’s
   shell. For details, see the “5.3. How to open a shell in the `/home` volume”
   section. If you get files associated to the wrong user, see the “6.3. How to
   change owners in batch” subsection bellow.

10. If everything is OK, you may run `make clean-bak` to delete everything in
    `bak/`.


### 6.3. How to change ownership in batch

If someday you need to transfer ownership of all files that belong to an user to
another, here is a way to do it:

**WARNING:** Some files in `/home` come from the `users` image. You should not
edit the ownership of these files.

1. Follow the procedure described in the “5.3. How to open a shell in the
   `/home` volume” section.

2. Run `chown -R --from=<old owner>:<old group> <new owner>:<new group> -- <files…>`,
   replacing `<old owner>`, `<old group>`, `<new owner>` and `<new group>` by
   the current owner, the current group, the new owner and the new group,
   respectively. `chown` automatically excludes files that do not have the
   ownership specified with the `--from` option. For details, see `man chown`.

If you need to swap the ownership between two users, you can create a temporary
user using `adduser` before running `chown`.


## 7. Uninstallation and cleaning

### 7.1. How to uninstall
To delete the Docker containers, images and volumes, see the `uninstall` and
`purge` targets of the `Makefile`.

**Note:** During the uninstallation, Docker Compose will raise errors for not
found images. It is normal: the `tk.bakfile_users` image is directly used by
multiple services, so Docker Compose tries to delete the same image multiple
times.


### 7.2. How to clean the project directory

To remove all your setting files and volume backups from the project directory,
see the `*clean` and `clean-*` targets of the `Makefile`.
