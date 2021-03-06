#!/bin/bash

urlscheme=http
port=80
domain=
curlflag=

usage() { echo -e "Usage: $0 -d domain [-s]\n  Select -s to use https to check host availability\n  Note that the SSL cert will not be validated" 1>&2; exit 1; }

while getopts "sd:" o; do
    case "${o}" in
        d)
            domain=${OPTARG}
            ;;
        s)
            urlscheme=https
	    curlflag=-k
	    port=443
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${domain}" ] ; then
    usage
fi

echo "domain = ${domain}"
echo "scheme = ${urlscheme}"

discovery(){
  hostalive $domain
  screenshot $domain
  cleanup $domain
  cat ./$domain/$foldername/responsive-$(date +"%Y-%m-%d").txt | sort -u | while read line; do
    sleep 1
    dirsearcher $line
    report $domain $line
    echo "$line report generated"
    sleep 1
  done
}

cleanup(){
  cd ./$domain/$foldername/screenshots/
  rename 's/_/-/g' -- *
  cd $path
}

hostalive(){
  cat ./$domain/$foldername/$domain.txt | sort -u | while read line; do
    if [ $(curl --write-out %{http_code} --silent --output /dev/null -m 5 $curlflag $urlscheme://$line) = 000 ]
    then
      echo "$line was unreachable"
      touch ./$domain/$foldername/unreachable.html
      echo "<b>$line</b> was unreachable<br>" >> ./$domain/$foldername/unreachable.html
    else
      echo "$line is up"
      echo $line >> ./$domain/$foldername/responsive-$(date +"%Y-%m-%d").txt
    fi
  done
}

screenshot(){
    echo "taking a screenshot of $line"
    python ~/tools/webscreenshot/webscreenshot.py -o ./$domain/$foldername/screenshots/ -i ./$domain/$foldername/responsive-$(date +"%Y-%m-%d").txt --timeout=10 -m
}

recon(){

  python ~/tools/Sublist3r/sublist3r.py -d $domain -t 10 -v -o ./$domain/$foldername/$domain.txt
  curl -s https://certspotter.com/api/v0/certs\?domain\=$domain | jq '.[].dns_names[]' | sed 's/\"//g' | sed 's/\*\.//g' | sort -u | grep $domain >> ./$domain/$foldername/$domain.txt
  discovery $domain
  cat ./$domain/$foldername/$domain.txt | sort -u > ./$domain/$foldername/$domain.txt

}

dirsearcher(){
  python3 ~/tools/dirsearch/dirsearch.py -e php,asp,aspx,jsp,html,zip,jar,sql -u $line
}


report(){
  touch ./$domain/$foldername/reports/$line.html
  echo "<title> report for $line </title>" >> ./$domain/$foldername/reports/$line.html
  echo "<html>" >> ./$domain/$foldername/reports/$line.html
  echo "<head>" >> ./$domain/$foldername/reports/$line.html
  echo "<link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css?family=Mina\" rel=\"stylesheet\">" >> ./$domain/$foldername/reports/$line.html
  echo "</head>" >> ./$domain/$foldername/reports/$line.html
  echo "<body><meta charset=\"utf-8\"> <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"> <link rel=\"stylesheet\" href=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/css/bootstrap.min.css\"> <script src=\"https://ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js\"></script> <script src=\"https://maxcdn.bootstrapcdn.com/bootstrap/3.3.7/js/bootstrap.min.js\"></script></body>" >> ./$domain/$foldername/reports/$line.html
  echo "<div class=\"jumbotron text-center\"><h1> Recon Report for <a/href=\"$urlscheme://$line.com\">$line</a></h1>" >> ./$domain/$foldername/reports/$line.html
  echo "<p> Generated by <a/href=\"https://github.com/nahamsec/lazyrecon\"> LazyRecon</a> on $(date) </p></div>" >> ./$domain/$foldername/reports/$line.html


  echo "   <div clsas=\"row\">" >> ./$domain/$foldername/reports/$line.html
  echo "     <div class=\"col-sm-6\">" >> ./$domain/$foldername/reports/$line.html
  echo "     <div style=\"font-family: 'Mina', serif;\"><h2>Dirsearch</h2></div>" >> ./$domain/$foldername/reports/$line.html
  echo "<pre>" >> ./$domain/$foldername/reports/$line.html
  cat ~/tools/dirsearch/reports/$line/* | while read rline; do echo "$rline" >> ./$domain/$foldername/reports/$line.html
  done
  echo "</pre>   </div>" >> ./$domain/$foldername/reports/$line.html

  echo "     <div class=\"col-sm-6\">" >> ./$domain/$foldername/reports/$line.html
  echo "<div style=\"font-family: 'Mina', serif;\"><h2>Screeshot</h2></div>" >> ./$domain/$foldername/reports/$line.html
  echo "<pre>" >> ./$domain/$foldername/reports/$line.html
  echo "Port 80                              Port 443" >> ./$domain/$foldername/reports/$line.html
  echo "<img/src=\"../screenshots/http-$line-80.png\" style=\"max-width: 500px;\"> <img/src=\"../screenshots/https-$line-443.png\" style=\"max-width: 500px;\"> <br>" >> ./$domain/$foldername/reports/$line.html
  echo "</pre>" >> ./$domain/$foldername/reports/$line.html

  echo "<div style=\"font-family: 'Mina', serif;\"><h2>Dig Info</h2></div>" >> ./$domain/$foldername/reports/$line.html
  echo "<pre>" >> ./$domain/$foldername/reports/$line.html
  dig $line >> ./$domain/$foldername/reports/$line.html
  echo "</pre>" >> ./$domain/$foldername/reports/$line.html

  echo "<div style=\"font-family: 'Mina', serif;\"><h2>Host Info</h1></div>" >> ./$domain/$foldername/reports/$line.html
  echo "<pre>" >> ./$domain/$foldername/reports/$line.html
  host $line >> ./$domain/$foldername/reports/$line.html
  echo "</pre>" >> ./$domain/$foldername/reports/$line.html

  echo "<div style=\"font-family: 'Mina', serif;\"><h2>Response Header</h1></div>" >> ./$domain/$foldername/reports/$line.html
  echo "<pre>" >> ./$domain/$foldername/reports/$line.html
  curl -sSL -D - $line  -o /dev/null >> ./$domain/$foldername/reports/$line.html
  echo "</pre>" >> ./$domain/$foldername/reports/$line.html

  echo "<div style=\"font-family: 'Mina', serif;\"><h1>Nmap Results</h1></div>" >> ./$domain/$foldername/reports/$line.html
  echo "<pre>" >> ./$domain/$foldername/reports/$line.html
  echo "nmap -sV -T3 -Pn -p3868,3366,8443,8080,9443,9091,3000,8000,5900,8081,6000,10000,8181,3306,5000,4000,8888,5432,15672,9999,161,4044,7077,4040,9000,8089,443,7447,7080,8880,8983,5673,7443" >> ./$domain/$foldername/reports/$line.html
  nmap -sV -T3 -Pn -p3868,3366,8443,8080,9443,9091,3000,8000,5900,8081,6000,10000,8181,3306,5000,4000,8888,5432,15672,9999,161,4044,7077,4040,9000,8089,443,7447,7080,8880,8983,5673,7443 $line >> ./$domain/$foldername/reports/$line.html
  echo "</pre></div>" >> ./$domain/$foldername/reports/$line.html


  echo "</html>" >> ./$domain/$foldername/reports/$line.html

}

logo(){
  #can't have a bash script without a cool logo :D
  echo "

  _     ____  ____ ___  _ ____  _____ ____ ____  _
 / \   /  _ \/_   \\  \///  __\/  __//   _Y  _ \/ \  /|
 | |   | / \| /   / \  / |  \/||  \  |  / | / \|| |\ ||
 | |_/\| |-||/   /_ / /  |    /|  /_ |  \_| \_/|| | \||
 \____/\_/ \|\____//_/   \_/\_\\____\\____|____/\_/  \|

                                                      "
}

main(){
  clear
  logo

  if [ -d "./$domain" ]
  then
    echo "This is a known target."
  else
    mkdir ./$domain
  fi
  mkdir ./$domain/$foldername
  mkdir ./$domain/$foldername/reports/
  mkdir ./$domain/$foldername/screenshots/
  touch ./$domain/$foldername/unreachable.html
  touch ./$domain/$foldername/responsive-$(date +"%Y-%m-%d").txt

    recon $domain
}
logo

path=$(pwd)
foldername=recon-$(date +"%Y-%m-%d")
main $domain
