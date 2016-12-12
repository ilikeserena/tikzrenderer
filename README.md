# tikzrenderer

Web server to render TikZ requests as SVG files.
See `tikzlive.html` how to embed it as javascript in an html page.
To see it in action, use:
```http
http://mywebserver.com/tikz/tikzlive.html
```
Rendering is implemented by <img> requests of the form:
```http
<img src='http://mywebserver.com/cgi-bin/tikzrendersvg.pl?tikz={tikzUri}'></img>
```
where `{tikzUri}` is an URI-encoded picture of the form `\begin{tikzpicture} ... \end{tikzpicture}`.

# SETUP (verified on Ubuntu 16.04 LTS 64-bits)

1. Install lampp (abbreviation for Linux-Apache-MySql-Php-Perl) on a linux system.
   Download from https://www.apachefriends.org/download.html.
2. Configure lampp to run CGI scripts by changing `/opt/lampp/etc/httpd.conf`.
   It should say `Options ExecCGI` in the `<Directory "/opt/lampp/cgi-bin">` section.
3. Start Apache with `sudo /opt/lampp/lampp startapache`.
   Verify Apache works by entering "http://localhost" in the address bar of a web browser.
   Verify CGI works by following the directions in `cgi-bin/test-cgi`
   and entering "http://localhost/cgi-bin/test-cgi" in the address bar of a web browser.
4. Install the tikz renderer functionality with:

 ```bash
cd /opt/lampp/cgi-bin
# Save whatever's there
sudo tar czpf ../cgi.tgz *
sudo rm -rf *
# Retrieve the tikz renderer functionality
sudo git clone https://github.com/ilikeserena/tikzrenderer.git ./
# Restore what we saved before
sudo tar xzpf ../cgi.tgz
sudo rm ../cgi.tgz
```
5. Create relevant directories, link files, and set permissions:
 ```bash
cd /opt/lampp/htdocs
sudo mkdir tikz
sudo mkdir tikz/tmp
sudo chown -R daemon:daemon tikz

cd /opt/lampp/cgi-bin
sudo ln *.png *.js tikzlive.html /opt/lampp/htdocs/tikz/
```
6. Install TIKZ software (Ubuntu):

 ```bash
sudo apt install texlive-latex-base
sudo apt install texlive-latex-extra
sudo apt install pdf2svg
sudo apt install lacheck
sudo apt install imagemagick
```
7. Verify installation with the following address in a web browser:
   "http://localhost/cgi-bin/tikztest.pl".
   It should show a page in which you can enter a tikz picture and submit it.
   For instance:
 ```latex
\begin{tikzpicture}
\draw (0,0) -- (1,1);
\end{tikzpicture}
```
   As a result we should see a .png image and a .svg image (see next item if SVG does not work).

   Alternatively, we can use:
   "http://localhost/tikz/tikzlive.html".
   It should show a live rendered .svg file that is updated whenever you stop typing for about a second.
   
8. Add support for SVG to the web server if it doesn't work.
   Edit /opt/lampp/etc/httpd.conf and add in the `<IfModule mime_module>` section:
 ```text
AddType image/svg+xml svg svgz
AddEncoding gzip svgz
```
   Restart Apache with `sudo /opt/lampp/lampp reloadapache`.
   Verify with the previous step (`tikztest.pl`) if .svg images work now.
   
9. Set up a cron job to get rid of spammy tikz requests.
 ```bash
sudo ln -s /opt/lampp/cgi-bin/cleanup_tikz /etc/cron.hourly/
```
   Verify it works by checking `/var/log/syslog` that should show "Running cleanup_tikz" after an hour, which should remove old files in the fashion specified in it.
   
10. Configure to run Apache automatically.
    The following procedure appears to be outdated, but it worked for me.
 ```bash
sudo ln -s /opt/lampp/lampp /etc/init.d/lampp
sudo update-rc.d lampp start 80 3 5 . stop 30 0 1 2 6 .
```
   Verify by restarting the machine and checking if the `tikztest.pl` step still works.
