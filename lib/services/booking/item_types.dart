import 'package:flutter/material.dart';

/// The item types a customer can book (owner decision 2026-10-26), in the
/// order shown. Same ids as the server (functions/src/lib/photoIntake.ts).
/// Which vehicles carry each type is set in the admin screen.
class ItemType {
  const ItemType(this.id, this.fr, this.en, this.es, this.icon);
  final String id, fr, en, es;
  final IconData icon;
  String label(String locale) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;
}

const itemTypes = <ItemType>[
  ItemType('sofa', 'Divan / sofa / sectionnel', 'Sofa / sectional', 'Sofá / seccional', Icons.weekend_outlined),
  ItemType('armchair', 'Fauteuil', 'Armchair', 'Sillón', Icons.chair_outlined),
  ItemType('bed', 'Lit / matelas / sommier', 'Bed / mattress / box spring', 'Cama / colchón / somier', Icons.bed_outlined),
  ItemType('dresser', 'Commode / armoire / bibliothèque', 'Dresser / wardrobe / bookcase', 'Cómoda / armario / librero', Icons.door_sliding_outlined),
  ItemType('desk', 'Bureau / chaise de bureau', 'Desk / office chair', 'Escritorio / silla de oficina', Icons.desk_outlined),
  ItemType('chairs', 'Chaises / tabourets', 'Chairs / stools', 'Sillas / taburetes', Icons.event_seat_outlined),
  ItemType('table', 'Table', 'Table', 'Mesa', Icons.table_restaurant_outlined),
  ItemType('tv_stand', 'Meuble TV / buffet', 'TV stand / sideboard', 'Mueble de TV / aparador', Icons.shelves),
  ItemType('tv', 'Téléviseur', 'TV', 'Televisor', Icons.tv_outlined),
  ItemType('fridge', 'Réfrigérateur', 'Refrigerator', 'Refrigerador', Icons.kitchen_outlined),
  ItemType('freezer', 'Congélateur', 'Freezer', 'Congelador', Icons.ac_unit),
  ItemType('washer', 'Laveuse / sécheuse', 'Washer / dryer', 'Lavadora / secadora', Icons.local_laundry_service_outlined),
  ItemType('stove', 'Cuisinière / lave-vaisselle', 'Stove / dishwasher', 'Estufa / lavavajillas', Icons.microwave_outlined),
  ItemType('tires', 'Pneus', 'Tires', 'Neumáticos', Icons.tire_repair_outlined),
  ItemType('yard_equipment', 'Souffleuse / tondeuse', 'Snow blower / lawn mower', 'Quitanieves / cortacésped', Icons.agriculture_outlined),
  ItemType('patio', 'Meubles de patio / BBQ', 'Patio furniture / BBQ', 'Muebles de patio / parrilla', Icons.outdoor_grill_outlined),
  ItemType('sport', 'Vélo / équipement de sport', 'Bike / sports equipment', 'Bicicleta / equipo deportivo', Icons.pedal_bike_outlined),
  ItemType('boxes', 'Boîtes / colis', 'Boxes / parcels', 'Cajas / paquetes', Icons.inventory_2_outlined),
  ItemType('materials', 'Matériaux de construction', 'Construction materials', 'Materiales de construcción', Icons.construction_outlined),
  ItemType('other', 'Autre objet', 'Other item', 'Otro objeto', Icons.category_outlined),
];

final itemTypeIds = {for (final t in itemTypes) t.id};

/// Item classes for the handling supplement (2026-10-26); same ids and
/// proposal as the server (functions/src/lib/itemClassFees.ts).
const itemClasses = ['light', 'medium', 'heavy', 'very_heavy'];

String itemClassLabel(String id, String locale) => switch (id) {
  'light' => locale == 'en' ? 'Light' : locale == 'es' ? 'Ligero' : 'Léger',
  'medium' => locale == 'en' ? 'Medium' : locale == 'es' ? 'Mediano' : 'Moyen',
  'heavy' => locale == 'en' ? 'Heavy' : locale == 'es' ? 'Pesado' : 'Lourd',
  _ => locale == 'en' ? 'Very heavy' : locale == 'es' ? 'Muy pesado' : 'Très lourd',
};

const proposedItemClasses = {
  'sofa': 'heavy', 'armchair': 'medium', 'bed': 'heavy', 'dresser': 'medium',
  'desk': 'medium', 'chairs': 'light', 'table': 'medium', 'tv_stand': 'medium',
  'tv': 'light', 'fridge': 'heavy', 'freezer': 'heavy', 'washer': 'heavy',
  'stove': 'heavy', 'tires': 'medium', 'yard_equipment': 'very_heavy',
  'patio': 'medium', 'sport': 'light', 'boxes': 'light',
  'materials': 'very_heavy', 'other': 'medium',
};

