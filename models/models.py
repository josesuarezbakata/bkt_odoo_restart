# -*- coding: utf-8 -*-
import http
from odoo import fields, models, api, _
from subprocess import Popen, PIPE, CalledProcessError

# import loggin para poder hacer "prints" por consola mediante el tail -f /var/log/odoo/odoo-server.log | grep odoo.addons.bkt_odoo_restart.models.models
import logging

_logger = logging.getLogger(__name__)

""" Clase la cual representa el modelo de el módulo en cuestión, que alberga tanto los
campos como el método que realiza el botón de reiniciar """
class BktReiniciarOdoo(models.TransientModel):
    
    _inherit = "res.config.settings"

    # Campo desplegable el cual va a albergar el nombre del módulo a actualizar
    modulo = fields.Many2one("ir.module.module", string="modulo", config_parameter = "bkt_odoo_restart.modulo")

    # _logger.info(self.env["ir.module.module"].search([('state', '=', 'installed')]).read(['name']))

    """ Método el cual actúa cuando se hace click en el botón de Reiniciar,
    el cual comprueba si está entre los modulos instalados y en caso afirmativo ejecutar 
    un Script de bash el cual actualiza el módulo elegido"""
    def reiniciar_odoo_function(self):
        # Datos necesarios para el funcionamiento del script sacados de Odoo
        nombre_base_datos_str = self.pool.db_name
        
        id_modulo = self.env["ir.config_parameter"].sudo().get_param("bkt_odoo_restart.modulo")
        nombre_modulo_str = self.env["ir.module.module"].search([('state', '=', 'installed'), ('id','=', id_modulo)]).read(['name'])[0]['name']

        # cmd = ['bash','/home/bakata/Escritorio/Script-Restart-Odoo/bkt_odoo_script.sh',nombre_base_datos_str,nombre_modulo_str]
        cmd = "bash /home/bakata/Escritorio/Script-Restart-Odoo/bkt_odoo_script.sh "+nombre_base_datos_str+" "+nombre_modulo_str
        with Popen(cmd, stdout=PIPE, stderr=PIPE) as p:
            for line in p.stdout:
                _logger.info(line) # process line here

        if p.returncode != 0:
            raise CalledProcessError(p.returncode, p.args)
        