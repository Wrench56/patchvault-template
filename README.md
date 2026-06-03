# PatchVault Template

PatchVault is a simple POSIX-compliant* system made for developers who still enjoy patching code the UNIX way. In today's world, some Git projects require fixes in dependencies that are not tracked (Please people, just use submodules with fixed commit hash...). In such cases, patches seem to be an elegant way of resolving the issue. The project was directly and by large influenced by the FreeBSD Ports repository.

*: Although I strived to make everything POSIX compliant, there are some tools that are not POSIX compliant due to several reasons:  [Since POSIX historically did not specify any cryptographic standards](https://wrench56.github.io/rant-why-does-posix-not-provide-crypto-utils/), I had to use either Linux' extended `cksum(1)`, FreeBSD's `sha256(1)`, Solaris' `digest(1)`, or the portable `OpenSSL(1)` dependencies. In addition, technically `curl(1)`, `wget(1)`, and `fetch(1)` are not POSIX either. In addition, the installer script also requires `~/.local/bin` to be in the PATH. Everything else is POSIX compliant. Please raise an issue if you spot anything that goes against this claim.

## Usage

### Using an Existing PatchVault

To start using a new PatchVault, it is advised for new users to start out by using the PatchVault (Standard) Tool, a.k.a `pvt`. One can install this using the following command:

```sh
curl -fsSL "https://raw.githubusercontent.com/Wrench56/patchvault-template/refs/heads/main/tools/pv-install.sh" | sh -s -- -s "https://raw.githubusercontent.com/Wrench56/patchvault-template/refs/heads/main/"
```

After installing `pvt`, the usage is pretty self-explanatory. It is advised to directly use `pvt`'s `patch` command over manually `fetch`-ing and `apply`-ing patchsets.

#### PVT-less Usage

Due to the deliberate structure of the project, it is rather simple to manually download a patchset and apply it. Fetch the patchset using your favorite "URL transfer tool" and apply it by going to the root of a project and executing `patch -p0 -N -i "<patch>"`.

### Creating a New PatchVault

Start by copying this repository. It is advised that one changes the above URLs to match the repositories (in case the tools diverge in either the template or in the User's repository). Install the tools using:

```sh
curl -fsSL "https://raw.githubusercontent.com/Wrench56/patchvault-template/refs/heads/main/tools/pv-install.sh" | sh -s -- -s -d -c "https://raw.githubusercontent.com/Wrench56/patchvault-template/refs/heads/main/"
```

It is advised that an automatic CI/CD pipeline be set up to run `pv-ci all` command ensuring every file is auto-updated.

## Repository Files

### index

`index` is an index file (surprise surprise!) that stores package names followed by a URL address of their respective `patchsets` file. In a way, `index` is an index file of index files.

> [!NOTE]
> The `index` file is automatically updated by `pv-ci`

### flags

`flags` contains all of the flags used by all patchset configurations. One can use this to de-duplicate flag usage. It is advised to keep the amount of flags as little as logically possible.

> [!NOTE]
> The `flags` file is automatically updated by `pv-ci`

## Package Files

### Patches

Each package has a directory called `patches/` containing individual file patches. Try to make them as modular as possible, as this will help with managing multiple patchsets.

### Patchsets

Patchsets are a collection of patches bundled together in a way that the end-user will not have any issues applying it. Also, it makes it easier for someone without the usual `pvt` standard tool to fetch and apply it. It also encourages the splitting of patches to ensure that other patchsets can reuse some of the patches written previously. The patchsets reside under the package's `sets/` directory.

> [!NOTE]
Patchsets are automatically assembled by `pv-ci`

### Patchset configurations

A patchset configuration is a KV file. It consists of the following keys:

- NAME
- DESC
- FLAGS
- PATCHES

Please follow the same order when specifying a patchset.

A patchset can have an arbitrary name but is required to have the `.conf` file extension. It is also required that all patchset configurations reside in the root of the package folder.

#### NAME

NAME is used as the name for the actual patchset. It should match `[A-Za-z0-9_]`.

#### DESC

A custom multiline description inserted into the header of the generated patchset.

#### FLAGS

A list of space separated flags which will be matched against when fetching a patch. These flags should be descriptive and describe the needed platform for a fetch.

Example #1:

You make a patch for a cross-platform tool -- such as an IRC server -- written in C. Unfortunately, a part of your fix is only valid for FreeBSD. You then proceed to create a new patch that fixes the small missing part on Linux. Now you create two patchsets: one for FreeBSD and one for Linux. Therefore, the flags should be something like `freebsd` and `linux`.

Example #2:

pyopengltk for X11 is broken. You fix the source code. However, some projects use venv, some use site-packages. You will need two separate patchsets. A nice flag would be something along the lines of `python_venv` or `python_site-packages`.

The exact form and conventions of flags should be decided by the PatchVault maintainer. Generally, I would recommend sticking with underscores and with specifier prefixes where it makes sense (e.g. `python_` is required but `freebsd` is self-explanatory and does not usually need `os_` prefix).

It is of course always a good idea to **reuse** flags. Read the global `flags` file in the root and reuse existing flags to remove the burden from the user of specifying new flags per package patch. 

#### PATCHES

A list of patches included in the patchset. It should be multiline:

```sh
PATCHES="
0000-fix-main.patch
0001-fix-printer.patch
"
```

### distinfo

Similarly to FreeBSD ports, each package has a distinfo. It contains all the SHA256 hashes of every single file contained in that package directory. During fetching, `pvt` checks the downloaded patchsets hash against the distinfo.

> [!NOTE]
> The `distinfo` files are automatically updated by `pv-ci`

### patchsets

`patchsets` is an index file for the given package. It contains the URLs of patchsets followed by their respective flags.

> [!NOTE]
> The `patchsets` files are automatically updated by `pv-ci`
