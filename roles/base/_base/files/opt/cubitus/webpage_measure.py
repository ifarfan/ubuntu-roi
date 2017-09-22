#!/usr/bin/env python
'''
Fetch webpage URL and analyze the size, latency time and file type of each downloaded file.

Args:
      url (str): URL to fetch
'''
from __future__ import print_function
import os, re, sys
import socket, time
from time import sleep
from urlparse import urlparse
import platform, pickle, struct


# Local Graphite server
CARBON_SERVER = '0.0.0.0'
CARBON_PORT = 2003
PICKLE_PORT = 2004


def send_packet(lines):
    # Send metrics to Graphite
    try:
        # payload = pickle.dumps(lines, protocol=2)
        payload = pickle.dumps(lines)
        header = struct.pack("!L", len(payload))
        msg = header + payload

        sock = socket.socket()
        sock.connect((CARBON_SERVER, PICKLE_PORT))
        sock.sendall(msg)
        sock.close()
    except:
        print("ERROR: Enable to connect to Graphite at %s:%s " % (CARBON_SERVER, PICKLE_PORT), file=sys.stderr)


def send_msg(msg):
    # Send metrics to Graphite
    try:
        sock = socket.socket()
        sock.connect((CARBON_SERVER, CARBON_PORT))
        sock.sendall(msg)
        sock.close()
    except:
        print("ERROR: Enable to connect to Graphite at %s:%s " % (CARBON_SERVER, CARBON_PORT), file=sys.stderr)



if __name__ == '__main__':

    # Get and validate URL
    if len(sys.argv) != 2:
        print("ERROR: Missing URL", file=sys.stderr)
        sys.exit(2)

    url=sys.argv[1]
    url_regex = re.compile(
            r'^(?:http|ftp)s?://'                                                                   # http:// or https://
            r'(?:(?:[A-Z0-9](?:[A-Z0-9-]{0,61}[A-Z0-9])?\.)+(?:[A-Z]{2,6}\.?|[A-Z0-9-]{2,}\.?)|'    # domain...
            r'localhost|'                                                                           # localhost...
            r'\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})'                                                  # ...or ip
            r'(?::\d+)?'                                                                            # optional port
            r'(?:/?|[/?]\S+)$', re.IGNORECASE)

    if  url_regex.match(url) is None:
        print("ERROR: Invalid URL: %s" % url, file=sys.stderr)
        sys.exit(2)

    # Sanitize URL for Graphite
    url_str = url.split("://")[1].rstrip('//').lower()
    url_str = re.sub('[^0-9a-zA-Z_]+', '_', url_str)

    # Download files
    try:
        os.system('wget --output-file=/tmp/%s --progress=bar:force --timeout=30 --tries=2 --delete-after --adjust-extension --span-hosts --convert-links --page-requisites %s' % (url_str, url))
    except:
        print("ERROR: Enable to fetch URL: %s" % url, file=sys.stderr)
        sys.exit(2)


    # Load File
    with open ("/tmp/" + url_str, "r") as myfile:
        log_lines=myfile.read()

    # Rate + Filename + Size
    rate_filename_size_speed_regex = re.compile(r"\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+\((\d*\.\d+|\d+)\s+(.*?)\)\s+-\s+\`(.*?)' saved \[(\d+).*?\]")
    rate_filename_size_speed_list = rate_filename_size_speed_regex.findall(log_lines)

    # URL
    url_regex = re.compile(r'--\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}--\s+(http.*)')
    url_list = url_regex.findall(log_lines)

    # Proto + Filename + URL
    proto_filename_url_list = [(url.split(":")[0], url.split("/")[-1], url) for url in url_list]

    # Code + Response
    code_response_regex = re.compile(r'HTTP request sent, awaiting response...\s+(\d{3})\s+(.*)')
    code_response_list  = code_response_regex.findall(log_lines)

    # Proto + Filename + URL + Code + Response
    proto_filename_url_code_response_list = [(x[0], 'index.html' if x[1] == '' else x[1], x[2], y[0], y[1]) for x, y in zip(proto_filename_url_list, code_response_list)]

    # List of downloaded vs non-downloaded URLs
    good_list = [(True,  proto, filename, url, code, response) for proto, filename, url, code, response in proto_filename_url_code_response_list if code == '200']
    bad_list  = [(False, proto, filename, url, code, response) for proto, filename, url, code, response in proto_filename_url_code_response_list if code != '200']

    good_downloaded_list = [(x[0], x[1], x[2], x[3], x[4], x[5], y[0], y[1], 0.00, y[2], y[3], 'other') for x, y in zip(good_list, rate_filename_size_speed_list)]
    bad_downloaded_list  = [(x[0], x[1], x[2], x[3], x[4], x[5], None, None, None, None, None, 'other') for x    in bad_list]

    downloaded_list = good_downloaded_list + bad_downloaded_list


    # Define file types
    temp_list = downloaded_list[:]

    # Find Images
    temp_list = [(x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9], x[10], 'img'  if x[11] == 'other' and any(k in x[2] for k in ['.png', '.jpeg', '.jpg', '.gif', '.svg']) else x[11]) for x in temp_list]

    # Find JS
    temp_list = [(x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9], x[10], 'js'   if x[11] == 'other' and any(k in x[2] for k in ['.js']) else x[11]) for x in temp_list]

    # Find CSS
    temp_list = [(x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9], x[10], 'css'  if x[11] == 'other' and any(k in x[2] for k in ['.css']) else x[11]) for x in temp_list]

    # Find HTML
    temp_list = [(x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9], x[10], 'html' if x[11] == 'other' and any(k in x[2] for k in ['.htm', '.html']) else x[11]) for x in temp_list]

    # Find Fonts
    temp_list = [(x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9], x[10], 'font' if x[11] == 'other' and any(k in x[2] for k in ['.woff', '.eot', '.ttf', '.otf']) else x[11]) for x in temp_list]

    # Find txt
    temp_list = [(x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9], x[10], 'txt'  if x[11] == 'other' and any(k in x[2] for k in ['.txt']) else x[11]) for x in temp_list]

    # Find Download Time (MB/s or KB/s)
    temp_list = [(x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7], int(x[10])/(float(x[6])*1024*1024) if x[10] is not None and any(k in x[7] for k in ['MB']) else x[8], x[9], x[10], x[11]) for x in temp_list]
    temp_list = [(x[0], x[1], x[2], x[3], x[4], x[5], x[6], x[7], int(x[10])/(float(x[6])*1024)      if x[10] is not None and any(k in x[7] for k in ['KB']) else x[8], x[9], x[10], x[11]) for x in temp_list]

    # Cleansed list
    downloaded_list = temp_list[:]


    # Some variables
    timestamp = int(time.time())


    # Build Graphite string
    lines = []
    counter = 0
    msg = ""
    for x in downloaded_list:
        counter += 1

        o = urlparse(x[3])
        domain = o.netloc
        domain = domain.lower()
        domain = re.sub('[^0-9a-z]+', '_', domain)

        filename = x[2]
        filename = filename.lower()
        filename = re.sub('[^0-9a-z]+', '_', filename)

        if x[10] is None:
            # Unresolved items
            lines.append(('urls.%s.%s.%s.%s.size' % (url_str, domain, x[11], filename), (timestamp, 0)))
            lines.append(('urls.%s.%s.%s.%s.time' % (url_str, domain, x[11], filename), (timestamp, 0)))
            # msg += 'urls.%s.%s.%s.%s.size 0 %d\n' % (url_str, domain, x[11], filename, timestamp)
            # msg += 'urls.%s.%s.%s.%s.time 0 %d\n' % (url_str, domain, x[11], filename, timestamp)
        else:
            # Downloaded items
            lines.append(('urls.%s.%s.%s.%s.size' % (url_str, domain, x[11], filename), (timestamp, x[10])))
            lines.append(('urls.%s.%s.%s.%s.time' % (url_str, domain, x[11], filename), (timestamp, x[8])))
            # msg += 'urls.%s.%s.%s.%s.size %s %d\n' % (url_str, domain, x[11], filename, x[10], timestamp)
            # msg += 'urls.%s.%s.%s.%s.time %s %d\n' % (url_str, domain, x[11], filename, x[8], timestamp)

        # HTTP/S and HTTP code
        # lines.append(('urls.%s.%s.%s.%s.https' % (url_str, domain, x[11], filename), (timestamp, "1" if x[1] == "https" else "0")))
        lines.append(('urls.%s.%s.%s.%s.http_code_%s' % (url_str, domain, x[11], filename, x[4]), (timestamp, 1)))
        # msg += 'urls.%s.%s.%s.%s.https %s %d\n' % (url_str, domain, x[11], filename, "1" if x[1] == "https" else "0", timestamp)
        # msg += 'urls.%s.%s.%s.%s.http_code_%s 1 %d\n' % (url_str, domain, x[11], filename, x[4], timestamp)

        # Send to Graphite every X iteration, reset counters
        if counter == 60:
            send_packet(lines)
            # send_msg(msg)
            time.sleep(4)
            lines = []
            counter = 0
            msg = ""


    if counter > 0 and len(lines) > 0:
        send_packet(lines)
        # send_msg(msg)


    # Delete file
    try:
        os.remove("/tmp/%s" % url_str)
    except OSError:
        pass