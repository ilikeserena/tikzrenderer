# tikzrenderer

SETUP ON A NEW SYSTEM
=====================

1. Install lampp on a linux system (https://www.apachefriends.org/download.html).

2. Configure lampp to run CGI scripts by changing /opt/lampp/etc/httpd.conf.
   It should say "Options ExecCGI" in the <Directory "/opt/lampp/cgi-bin"> section.
   
3. Start Apache with "sudo /opt/lampp/lampp startapache".
   Verify Apache works by entering "http://localhost" in the address bar of a web browser.
   Verify CGI works by following the directions in cgi-bin/test-cgi
   and entering "http://localhost/cgi-bin/test-cgi" in the address bar of a web browser.

4. Install the tikz renderer functionality with:
   cd /opt/lampp
   # Retrieve cgi-bin scripts
   cd cgi-bin
   sudo git clone https://github.com/ilikeserena/tikzrenderer.git ./
   cd ..
   
5. Create relevant directories and set permissions:
   cd htdocs
   sudo mkdir tikz
   sudo mkdir tikz/tmp
   # Fix permissions so that requests to cgi-bin scripts can create files in those directories
   sudo chown daemon:daemon tikz
   sudo chown daemon:daemon tikz/tmp

6. Install TIKZ software:
   sudo apt install texlive-latex-base
   sudo apt install texlive-latex-extra
   sudo apt install pdf2svg
   sudo apt install lacheck

7. Verify installation with the following address in a web browser:
   http://localhost/cgi-bin/tikztest.pl
   It should show a page in which you can enter a tikz picture and submit it.
   For instance:
    \begin{tikzpicture} \draw (0,0) -- (1,1); \end{tikzpicture}
   As a result we should see a .png image and a .svg image (see next item if SVG does not work).

8. Add support for SVG to the web server if it doesn't work:
   Edit /opt/lampp/etc/httpd.conf and add in the <IfModule mime_module> section:
    AddType image/svg+xml svg svgz
    AddEncoding gzip svgz
   Restart Apache with "sudo /opt/lampp/lampp reloadapache".

9. Set up a cron job to get rid of spammy tikz requests.
   Create /etc/cron.hourly/cleanup_tikz with contents:
    #!/bin/bash
    logger "Running cleanup_tikz"
    find /opt/lampp/htdocs/tikz -name "live_*" -mtime +1 -exec rm {} \;
    find /opt/lampp/htdocs/tikz -name "preview_*" -mtime +1 -exec rm {} \;
   Set permissions with:
    sudo chmod a+x /etc/cron.hourly/cleanup_tikz
   Verify it works by checking /var/log/syslog that should show "Running cleanup_tikz" after an hour.

10. Configure to run Apache automatically (Ubuntu)
    sudo ln -s /opt/lampp/lampp /etc/init.d/lampp
    sudo update-rc.d lampp start 80 3 5 . stop 30 0 1 2 6 .
