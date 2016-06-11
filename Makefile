# See `README` and below.

# The name of Docker images, in order they have to be generated.
IMAGES=tk.bakfile.users tk.bakfile.data tk.bakfile.rsync tk.bakfile.duplicity tk.bakfile.gpg

USERS_IMAGE=tk.bakfile.users
DATA_IMAGE=tk.bakfile.data
RSYNC_IMAGE=tk.bakfile.rsync

# Name of the archive in `bak/` (`export` and `import`).
VOLUME_TAR=volumes.tar
# Volumes to export/import (`export` and `import`). Use absolute paths.
VOLUMES=/home
# Path of the backup directory on the host (`export` and `import`).
HOST_BAK_DIRECTORY:=bak
# Temporary path for the backup directory on the container (`export` and
# `import`).
CONTAINER_BAK_DIRECTORY=/bak

DOCKER=sudo docker


# Builds the Docker images.
.PHONY: images
images:
	for i in $(IMAGES); do echo; echo "$$i:"; $(DOCKER) build -t "$$i" "src/$$i" || exit; done

# Remove user list, default users’ keys and `bak`.
.PHONY: distclean mostlyclean maintainer-clean
distclean mostlyclean maintainer-clean: clean clean-bak
	rm -rf src/${USERS_IMAGE}/root/ssh-auth-keys src/${USERS_IMAGE}/root/rsync-users

# Removes the files in `bak`.
.PHONY: clean-bak
clean-bak:
	rm -f bak/*

.PHONY: clean
clean:
	# No generated files.


# Deletes any stopped container (volumes included) that has the same name than
# a Docker image generated by this `Makefile`.
#
# WARNING: Since this target should delete the `/home` volume, `make export`
# should be run first. It also a good idea to double-check the archive generated
# by `make export`.
.PHONY: clean-ps
clean-ps:
	$(DOCKER) rm -v $(IMAGES)

# Creates a container for `tk.bakfile.data`.
.PHONY: run-data
run-data:
	$(DOCKER) run --name="${DATA_IMAGE}" "${DATA_IMAGE}"

# Runs `bash` in the `tk.bakfile.data` image.
.PHONY: debug-data
debug-data:
	$(DOCKER) run -ti -w /home --rm --volumes-from="${DATA_IMAGE}" "${DATA_IMAGE}" /bin/bash

# Runs `sshd -t` in the `tk.bakfile.rsync` image.
.PHONY: test-rsync
test-rsync:
	$(DOCKER) run --rm --volumes-from="${DATA_IMAGE}" "${RSYNC_IMAGE}" -t

# Exports `/home` as `bak/volumes.tar`.
#
# Note: The usage of backquotes (contrary to `$(…)`) force `make` to pass the
# subcommand as-is to the Bourne Shell so we can ensure that
# `"${HOST_BAK_DIRECTORY}"` exists before trying to run
# `realpath "${HOST_BAK_DIRECTORY}"`.
.PHONY: export
export:
	mkdir -p "${HOST_BAK_DIRECTORY}"
	$(DOCKER) run --rm --volumes-from="${DATA_IMAGE}" --volume="`realpath "${HOST_BAK_DIRECTORY}"`:${CONTAINER_BAK_DIRECTORY}" "${DATA_IMAGE}" /bin/tar -cf "/bak/${VOLUME_TAR}" --atime-preserve $(VOLUMES)

# Imports `/home` from `bak/volumes.tar`.
#
# Assumes that the `tk.bakfile.data` container exists.
#
# WARNING: This overwrite files without asking.
#
# Note: The usage of backquotes (contrary to `$(…)`) force `make` to pass the
# subcommand as-is to the Bourne Shell so we can ensure that
# `"${HOST_BAK_DIRECTORY}"` exists before trying to run
# `realpath "${HOST_BAK_DIRECTORY}"`.
.PHONY: import
import:
	mkdir -p "${HOST_BAK_DIRECTORY}"
	$(DOCKER) run --rm --volumes-from="${DATA_IMAGE}" --volume="`realpath "${HOST_BAK_DIRECTORY}"`:${CONTAINER_BAK_DIRECTORY}" "${DATA_IMAGE}" /bin/tar -xpf "/bak/${VOLUME_TAR}" -C / --atime-preserve --overwrite

# Ensures the backup directory exists.
.PHONY: bak-directory
bak-directory:
	mkdir -p "${HOST_BAK_DIRECTORY}"
