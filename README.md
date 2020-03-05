# eMastercard2Nart

Migrate an [eMastercard](https://github.com/HISMalawi/E-MasterCard-BackEnd) database
to a [NART](https://github.com/HISMalawi/BHT-Core-Apps-ART) database.

## Requirements

- [Ruby 2.5](https://ruby-lang.org)
- [bundler](https://bundler.io)
- MySQL client development libraries if on Linux (see [Setup](#setup) below).

## Setup (applies to Debian/Ubuntu)

The application can be setup in one of two ways, using a setup script or manually
setting up the application. Use of the automated setup requires
[rvm](https://rvm.io/rvm/install) to be installed, otherwise the manual setup is
the way to go. NOTE: All commands below assume you are running a Debian based
Linux distribution with `sudo` setup for the logged in user.

### 1. Automated setup

```bash
$ chmod a+x setup.sh
$ sudo setup.sh
```

### 2. Manual setup

1. Install libmysqlclient and ruby-dev:

    ```bash
    $ sudo apt install default-libmysqlclient-dev ruby-dev
    ```

2. Install ruby 2.5.3 using whatever method is preferred (recommended is
   [rvm](https://rvm.io/rvm/install)). Assuming `rvm` is available, do the
   following:

   ```bash
   $ rvm install ruby-2.5.3
   ```

3. Install dependencies:

    ```bash
    $ rvm use 2.5.3 # skip if rvm is not available
    $ bundle install
    ```
4. Copy configuration file:

    ```bash
    $ cp config.yaml.example config.yaml
    ```

## Configuration

Application configuration is held in `config.yaml` at the root of the application.
The following section describes what each variable in the configuration file
does:

  * site_prefix: This is prepended to the ARV number, it must be the same as what
                 is in use on the target NART server (For example if ABC is site prefix then emastercard ARV number 1 will be transformed to ARV-ABC-1).
  * emr_user_id: Every record created in the NART database needs to have an associated
                 creator user. This can be left unchanged; the default should work on
                 most NART servers but if doesn't then grab a user id from the users
                 table in the NART database.
  * emr_location_id: Serves a similar purpose as `emr_user_id` above but this points to
                     the workstation in use. Can also be left as is.
  * emastercard: This section is for pointing the application to the eMastercard database.
                 It should be self explanatory, if not then you probably shouldn't be doing this.
  * emr: Similar to the `emastercard` section above.

## Running

```bash
$ ruby main.rb
```

The command above starts the migration. When the migration is done or terminated it writes
any errors met during processing of the records to `errors.yaml`. That file can be used to
correct any problems in the data (errors logged in there include 'missing required vitals and drugs dispensed'). The same file is also used to continue the migration the next time the script is run.
If there is any need to restart the entire process then `errors.yml` must be removed.