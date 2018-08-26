# /usr/bin/env python

import time
import argparse
import atexit
import sys
import os
from xvfbwrapper import Xvfb

from graffiti.request import Request, Type, Host


class RenderingParams(object):

    def __init__(self):
        self.crs = None
        self.width = 1629
        self.height = 800
        self.format = "png"


def init_environment(root):

    # PYTHONPATH
    pythonpath = '{}/share/qgis/python'.format(root)
    sys.path.append(pythonpath)

    # LD_LIBRARY_PATH
    os.environ['LD_LIBRARY_PATH'] = '{}/lib'.format(root)

    # qgis imports
    global QgsDataSourceUri
    global QgsVectorLayer
    global QgsMapSettings
    global QSize
    global QgsCoordinateReferenceSystem
    global QgsMapCanvas
    global QImage
    global Qt
    global QPainter
    global QgsMapRendererCustomPainterJob
    global QgsMapLayerRegistry
    global QgsProject

    try:
        from qgis.core import Qgis
    except ImportError:
        from qgis.core import QGis as Qgis

    version = int(Qgis.QGIS_VERSION_INT)

    if version < 30000:
        from qgis.core import (QgsDataSourceURI as QgsDataSourceUri,
                               QgsVectorLayer,
                               QgsProject,
                               QgsMapLayerRegistry,
                               QgsApplication,
                               QgsMapSettings,
                               QgsMapRendererCustomPainterJob,
                               QgsCoordinateReferenceSystem)

        from qgis.gui import QgsMapCanvas


        from PyQt4.QtCore import QSize, Qt
        from PyQt4.QtGui import QApplication, QImage, QPainter, QColor
    else:
        from qgis.core import (QgsDataSourceUri,
                               QgsVectorLayer,
                               QgsProject,
                               QgsApplication,
                               QgsMapSettings,
                               QgsMapRendererCustomPainterJob,
                               QgsCoordinateReferenceSystem)

        from qgis.gui import QgsMapCanvas

        from PyQt5.QtCore import QSize, Qt
        from PyQt5.QtGui import QImage, QPainter, QColor
        from PyQt5.QtWidgets import QApplication

    # init xvfb
    vdisplay = Xvfb()
    vdisplay.start()
    atexit.register(vdisplay.stop)

    # init application
    app = QApplication([])
    QgsApplication.setPrefixPath(root, True)
    QgsApplication.initQgis()

    return version, app


def layer(args):

    vl = None
    provider = args.provider

    if provider == 'postgres':
        uri = QgsDataSourceUri()
        uri.setConnection(args.pg_host, '5432', args.pg_db, args.pg_user, args.pg_pwd)
        uri.setDataSource(args.pg_schema, args.pg_table, args.pg_geom, '', args.pg_id)
        vl = QgsVectorLayer(uri.uri(), 'layer', provider)

    return vl


def render(version, args, config):

    # get layer
    vl = layer(args)

    if not vl.isValid():
        print('ERROR: Invalid layer')
        app.exit()
        sys.exit(1)

    # init map setting
    ms = QgsMapSettings()

    extent = vl.extent()
    ms.setExtent(extent)

    size = QSize(config.width, config.height)

    crs = QgsCoordinateReferenceSystem(config.crs)
    ms.setOutputSize(size)
    ms.setDestinationCrs(crs)

    # init a canvas object
    parser.add_argument('host', type=str, help='Database host (postgres provider)')
    canvas = QgsMapCanvas()
    canvas.setDestinationCrs(crs)

    if version < 30000:
        QgsMapLayerRegistry.instance().addMapLayer(vl, False)
        ms.setLayers([vl.id()])
    # QGIS 3 specific
    else:
        canvas.setLayers([vl])
        ms.setLayers([vl])

    i = QImage(size, QImage.Format_RGB32)
    i.fill(Qt.white)
    p = QPainter(i)
    j = QgsMapRendererCustomPainterJob(ms, p)

    start = time.time()
    j.renderSynchronously()
    t = time.time() - start

    p.end()
    i.save(args.output)

    return t


def server(args, config):

    h = Host('master', args.server_host)
    h.payload['MAP'] = '/data/data_perf.qgs'
    h.payload['VERSION'] = '1.3.0'
    h.payload['WIDTH'] = config.width
    h.payload['HEIGHT'] = config.height
    h.payload['SRS'] = config.crs
    h.payload['FORMAT'] = config.format
    h.payload['LAYERS'] = args.pg_table

    r = Request('master', Type.GetMap, [h], iterations=2, title='', logdir='/tmp')
    r.run()
    
    print(r.durations)


if __name__ == "__main__":

    # parse args
    descr = 'Measure rendering time'
    parser = argparse.ArgumentParser(description=descr)
    parser.add_argument('root', type=str, help='QGIS installation root')
    parser.add_argument('provider', type=str, help='Provider')
    parser.add_argument('output', type=str, help='PNG output image')

    parser.add_argument('-pg-host', type=str, help='Database host (postgres)')
    parser.add_argument('-pg-db', type=str, help='Database name (postgres)')
    parser.add_argument('-pg-user', type=str, help='Database user (postgres)')
    parser.add_argument('-pg-pwd', type=str, help='Database password (postgres)')
    parser.add_argument('-pg-schema', type=str, help='Database schema (postgres)')
    parser.add_argument('-pg-table', type=str, help='Database table (postgres)')
    parser.add_argument('-pg-geom', type=str, help='Database geom (postgres)')
    parser.add_argument('-pg-id', type=str, help='Database id for views (postgres)')

    parser.add_argument('--server', action='store_true')
    parser.add_argument('-server-host', type=str, help='QGIS Server host')

    args = parser.parse_args()

    # init environment
    version, app = init_environment(args.root)

    # render
    c = RenderingParams()
    c.crs = 'EPSG:2154'

    t_headless = render(version, args, c)
    print('Headless rendering time: {} '.format(t_headless))

    # server rendering
    if args.server:
        t_server = server(args, c)
        print('Server rendering time: {} '.format(t_server))

    # terminate
    app.exit()
    sys.exit(0)
