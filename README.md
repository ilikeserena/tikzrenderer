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

# SETUP (Linux Ubuntu)

1. Install apache2 and enable PerlCGI

 ```bash
sudo apt install apache2
sudo apt install libcgi-session-perl
sudo a2enmod cgid
sudo service apache2 restart
``` 
2. Get the tikz renderer functionality with:

 ```bash
sudo apt install git
sudo git clone https://github.com/ilikeserena/tikzrenderer.git
```
3. Create relevant directories, link files, and set permissions:

 ```bash
SOURCE=$PWD/tikzrenderer
CGI_BIN=/usr/lib/cgi-bin
HTML=/var/www/html
sudo cp -R $SOURCE/*.pl $SOURCE/*.sty $CGI_BIN/
sudo mkdir -p $HTML/tikz/tmp
sudo cp $SOURCE/favicon.ico $HTML/
sudo cp $SOURCE/*.png $SOURCE/*.js $SOURCE/tikzlive.html $HTML/tikz/
sudo chown -R www-data:www-data $HTML/tikz
```
4. Install TIKZ software (Ubuntu):

 ```bash
sudo apt install texlive-latex-extra
sudo apt install pdf2svg
sudo apt install lacheck
sudo apt install imagemagick
```
5. Verify installation with the following address in a web browser:
   "http://localhost/tikz/tikzlive.html".
   It should show a live rendered .svg file that is updated whenever you stop typing for about a second.
   For instance:
 ```latex
\begin{tikzpicture}
\draw (0,0) -- (1,1);
\end{tikzpicture}
```
   As a result we should see a .svg image (see next item if SVG does not work).

6. Set up a cron job to get rid of spammy tikz requests.

 ```bash
sudo cp $SOURCE/cleanup_tikz /etc/cron.hourly/
```
   Verify it works by checking `/var/log/syslog` that should show "Running cleanup_tikz" after an hour, which should remove old files in the fashion specified in it.
