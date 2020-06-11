# perl-scripts

Utility Perl Scripts

## Mine Jenkins Plugins (_get_jenkins_plugins.pl_)

__About__: Scrape the Jenkins Updates repository for latest version of plugins, download the plugins, and create an archive.

__Usage__: ./get_jenkins_plugins.pl [ --all | --filter "pattern" ] --dest-path "downloads location" --help

Invoke _./get_jenkins_plugins.pl --help_ for usage information/examples

Notes:
* The required --all or --filter options must be used
* Using --dest-path recommended (this were the *hpi files are dumped)
* Ensure that LWP::Simple is installed

Include the /bin path in the PATH var
Use relative path below or export PERL5LIB var to include the /lib path

Example:
```
export PATH=/home/svpineo/perl-scripts/bin:$PATH
export PERL5LIB=/home/svpineo/perl-scripts/lib`
```
## Quotations/Authors Information Scraping

Included in the _bin/quotes_ directory are scripts used for scraping quotations and authors information. For more information review the script description and/or use the --usage command-line option.
