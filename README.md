# tikzrenderer

SETUP ON A NEW SYSTEM
=====================

1. Install lampp on a linux system (https://www.apachefriends.org/download.html).

2. Execute the following commands in a bash shell:

cd <lampp directory>
# Retrieve cgi-bin scripts
cd cgi-bin
git clone https://github.com/ilikeserena/tikzrenderer.git ./
cd ..
# Create relevant directories
cd htdocs
mkdir tikz
mkdir tikz/tmp
# Fix permissions so that requests to cgi-bin scripts can create files in those directories

3. Verify installation with the following address in a web browser:
http://localhost/cgi-bin/tikztest.pl
It should show a page in which you can enter a tikz picture and submit it.

4. Set up a cron job to get rid of spammy tikz requests
