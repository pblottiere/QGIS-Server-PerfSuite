# /usr/bin/env python

import time
import argparse
import atexit
import sys
import os
from xvfbwrapper import Xvfb


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

    return version, app, vdisplay


def layer(args):

    vl = None
    provider = args.provider

    if provider == 'postgres':
        uri = QgsDataSourceUri()
        uri.setConnection(args.host, '5432', args.db, args.user, args.pwd)
        uri.setDataSource(args.schema, args.table, args.geom, '', args.id)
        vl = QgsVectorLayer(uri.uri(), 'layer', provider)

    return vl


def render(version, vl, output):

    # init map setting
    ms = QgsMapSettings()

    extent = vl.extent()
    ms.setExtent(extent)

    size = QSize(1629, 800)

    crs = QgsCoordinateReferenceSystem("EPSG:2154")
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
    i.save(output)

    return t


if __name__ == "__main__":

    # parse args
    descr = 'Measure rendering time'
    parser = argparse.ArgumentParser(description=descr)
    parser.add_argument('root', type=str, help='QGIS installation root')
    parser.add_argument('provider', type=str, help='Provider')
    parser.add_argument('output', type=str, help='PNG output image')

    # postgres provider args
    parser.add_argument('-host', type=str, help='Database host (postgres)')
    parser.add_argument('-db', type=str, help='Database name (postgres)')
    parser.add_argument('-user', type=str, help='Database user (postgres)')
    parser.add_argument('-pwd', type=str, help='Database password (postgres)')
    parser.add_argument('-schema', type=str, help='Database schema (postgres)')
    parser.add_argument('-table', type=str, help='Database table (postgres)')
    parser.add_argument('-geom', type=str, help='Database geom (postgres)')
    parser.add_argument('-id', type=str, help='Database id for views (postgres)')

    args = parser.parse_args()

    # init environment
    version, app, vdisplay = init_environment(args.root)

    # get layer
    vl = layer(args)

    if not vl.isValid():
        print('ERROR: Invalid layer')
        app.exit()
        sys.exit(1)

    # render
    t = render(version, vl, args.output)
    print('Rendering time: {} '.format(t))

    # terminate
    app.exit()
    sys.exit(0)
