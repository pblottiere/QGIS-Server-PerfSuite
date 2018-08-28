#! /usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import os
import glob
import datetime
import csv
from datetime import datetime
import shutil

from graffiti import Config, Request, Graph, Report

ROTATIVE_DAYS = 15
GRAFFITI_DATE_FORMAT = '%Y-%m-%d %H:%M:%S'
CACHE_FORMAT_DATE = '%Y_%m_%d_%H_%M_%S'


def update_cache(indir, logdir, cachedir, date):
    date = datetime.strptime(date, GRAFFITI_DATE_FORMAT)

    # create cache if necessary
    if not os.path.exists(cachedir):
        os.makedirs(cachedir)

    # clear rotative backup
    toclear = []
    for f in os.listdir(cachedir):
        if os.path.isdir(os.path.join(cachedir, f)):
            date = datetime.strptime(f, CACHE_FORMAT_DATE)
            delta = datetime.now() - date
            if delta.days > ROTATIVE_DAYS:
                toclear.append(os.path.join(cachedir, f))

    for d in toclear:
        shutil.rmtree(d, ignore_errors=True)

    # create new dir in cache
    newdir = os.path.join(cachedir, date.strftime(CACHE_FORMAT_DATE))
    if not os.path.exists(newdir):
        os.makedirs(newdir)

    # store some files from graffiti
    os.chdir(logdir)
    for f in glob.glob("*.csv"):
        shutil.copy2(f, newdir)


def read_cache_for_scenario(cachedir, cfg):
    cached_requests = []

    # for each request
    for req_cfg in graffiti_cfg.requests:
        req = Request.build(req_cfg)
        req.csv = []  # add an attribute

        csvname = '{}.csv'.format(req_cfg.name)

        # search the corresponding csv file for the request per date
        for root, dirs, files in os.walk(cachedir):
            for file in files:
                if file == csvname:
                    req.csv.append(os.path.join(root, file))

        cached_requests.append(req)

    for r in cached_requests:
        for csvfile in r.csv:
            duration = []
            with open(csvfile, newline='') as f:
                reader = csv.reader(f, delimiter=' ', quotechar='|')
                row_master = None
                for row in reader:
                    # header
                    if not row_master:
                        for i, j in enumerate(row):
                            if j == '3.0':
                                row_master = i
                    # data
                    else:
                        duration.append(float(row[row_master]))

            dirname = os.path.basename(os.path.dirname(csvfile))
            d = datetime.strptime(dirname, CACHE_FORMAT_DATE)
            key = datetime.strftime(d, GRAFFITI_DATE_FORMAT)

            r.durations[key] = duration

    return cached_requests


def build_graphs(cache, outdir):
    graphs = []
    outdir = os.path.join(outdir, 'graph')
    os.makedirs(outdir)

    for request in cache:
        print(request.durations)

        g = Graph(request)
        g.draw(outdir)

        graphs.append(g)

    return graphs


def build_report(outdir, graphs, date, desc):
    report = Report(date)

    for graph in graphs:
        report.add(graph)

    html = os.path.join(outdir, 'summary.html')
    report.write(html, desc)


if __name__ == '__main__':
    descr = 'Generate HTML summary report'
    parser = argparse.ArgumentParser(description=descr)
    parser.add_argument('cfg', metavar='cfg', type=str,
                        help='Configuration file for graffiti')
    parser.add_argument('cachedir', metavar='cachedir', type=str,
                        help='Cache directory')
    parser.add_argument('outdir', metavar='outdir', type=str,
                        help='Output directory')
    args = parser.parse_args()

    # read graffiti scenario
    graffiti_cfg = Config(args.cfg, new=False)

    # create output dir
    if os.path.exists(args.outdir):
        shutil.rmtree(args.outdir, ignore_errors=True)
    os.makedirs(args.outdir)

    # build report
    update_cache(graffiti_cfg.outdir, graffiti_cfg.logdir, args.cachedir,
                 graffiti_cfg.date)
    cache = read_cache_for_scenario(args.cachedir, args.cfg)
    graphs = build_graphs(cache, args.outdir)
    build_report(args.outdir, graphs, graffiti_cfg.date, graffiti_cfg.desc)
