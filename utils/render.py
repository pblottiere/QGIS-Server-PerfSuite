import time
import argparse
import sys
import os


def init_environment(root):

    # PYTHONPATH
    pythonpath = '{}/share/qgis/python'.format(root)
    sys.path.append(pythonpath)

    # LD_LIBRARY_PATH
    os.environ['LD_LIBRARY_PATH'] = '{}/lib'.format(root)
    os.execv(sys.argv[0], sys.argv)

    # Import
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
                               QgsRectangle,
                               QgsMapRendererCustomPainterJob,
                               QgsPalLayerSettings,
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
                               QgsRectangle,
                               QgsMapRendererCustomPainterJob,
                               QgsPalLayerSettings,
                               QgsCoordinateReferenceSystem)

        from qgis.gui import QgsMapCanvas

        from PyQt5.QtCore import QSize, Qt
        from PyQt5.QtGui import QImage, QPainter, QColor
        from PyQt5.QtWidgets import QApplication

    # init application
    app = QApplication([])
    QgsApplication.setPrefixPath(root, True)
    QgsApplication.initQgis()

    return app, version


def layer(args):

    provider = args.provider

    uri = QgsDataSourceUri()
    uri.setConnection( "172.17.0.3", "5432", "data", "root", "root")
    uri.setDataSource("ref", "hydro_bassin", "geoml93", "")
    return QgsVectorLayer( uri.uri(), "layer", provider)


def render(version, vl, output):

    # init map setting
    ms = QgsMapSettings()

    extent = vl.extent()
    ms.setExtent( extent )

    size = QSize(1629, 800)

    crs = QgsCoordinateReferenceSystem("EPSG:2154")
    ms.setOutputSize( size )
    ms.setDestinationCrs(crs)

    project = QgsProject.instance()

    # init a canvas object
    canvas = QgsMapCanvas()
    canvas.setDestinationCrs(crs)

    if version < 30000:
        QgsMapLayerRegistry.instance().addMapLayer(vl)

    # QGIS 3 specific
    if version >= 30000:
        project.addMapLayers([vl])

        canvas.setLayers([vl])
        ms.setLayers([vl])

    i = QImage(size, QImage.Format_RGB32)
    i.fill( Qt.white )
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
    args = parser.parse_args()

    # init environment
    app, version = init_environment(args.root)

    # get layer
    vl = layer(args)

    if not vl.isValid():
        print('ERROR: Invalid layer')
        app.exit()
        sys.exit(1)

    print('Feature count: {}'.format(vl.featureCount()))

    # render
    time = render(version, vl, args.output)
    print('Rendering time: {}'.format(time))

    # terminate
    app.exit()
    sys.exit(0)
