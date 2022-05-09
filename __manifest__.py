# -*- coding: utf-8 -*-
{
    'name': "Bakata Reinicio de Odoo",
    'version': '0.1',
    'summary':'Módulo el cual permite actualizar un módulo antes de reiniciar el Odoo.',
    'author':'Bakata',
    'sequence': 10,
    'category': 'Services/Project',
    'description': "Módulo en el cual se le permite actualizar un módulo pasado por parámetro junto con el reinicio de Odoo pertinente.",
    'website': 'https://github.com/josesuarezbakata/Script-Restart-Odoo',
    
    'depends': [
        'base_setup'
    ],
    
    'data': [
        'views/ajustes_projecto_view.xml'
    ],
    'installable': True,
    'application': True,
    'auto_install': False,
}