/// Common buildings and locations at Universidad de los Andes campus.
/// Used as a pick-list when posting items so buyers know the meeting point.
/// Keep this list alphabetically sorted for easy lookup.
const List<String> uniAndesBuildings = [
  'Edificio Mario Laserna (ML)',
  'Biblioteca General',
  'Aulas',
  'Bloque G',
  'Bloque Ñf',
  'Bloque Q',
  'Bloque R',
  'Bloque Rgd',
  'Bloque W',
  'Bloque Z',
  'Centro Deportivo',
  'Bloque Tx',
  'Edificio Franco',
  'Edificio Pedro Navas',
  'Edificio Santo Domingo',
  'Food Trucks',
  'La Gata Golosa - Caneca',
  'Centro del Japon',
  'Lleras',
  'Plazoleta Central',
  'Plazoleta del Edificio ML',
  'Senda Peatonal',
];

/// GPS coordinates (latitude, longitude) for each building.
/// Used by the location service to determine the user's nearest building.
class BuildingCoords {
  final double lat;
  final double lng;
  const BuildingCoords(this.lat, this.lng);
}

const Map<String, BuildingCoords> buildingCoordinates = {
  'Edificio Mario Laserna (ML)': BuildingCoords(4.60280, -74.06520),
  'Biblioteca General': BuildingCoords(4.60170, -74.06470),
  'Aulas': BuildingCoords(4.60230, -74.06430),
  'Bloque G': BuildingCoords(4.60150, -74.06390),
  'Bloque Ñf': BuildingCoords(4.60190, -74.06540),
  'Bloque Q': BuildingCoords(4.60130, -74.06450),
  'Bloque R': BuildingCoords(4.60110, -74.06500),
  'Bloque Rgd': BuildingCoords(4.60100, -74.06480),
  'Bloque W': BuildingCoords(4.60050, -74.06520),
  'Bloque Z': BuildingCoords(4.60070, -74.06560),
  'Centro Deportivo': BuildingCoords(4.60320, -74.06600),
  'Bloque Tx': BuildingCoords(4.60160, -74.06560),
  'Edificio Franco': BuildingCoords(4.60090, -74.06420),
  'Edificio Pedro Navas': BuildingCoords(4.60250, -74.06480),
  'Edificio Santo Domingo': BuildingCoords(4.60200, -74.06350),
  'Food Trucks': BuildingCoords(4.60260, -74.06560),
  'La Gata Golosa - Caneca': BuildingCoords(4.60180, -74.06500),
  'Centro del Japon': BuildingCoords(4.60140, -74.06530),
  'Lleras': BuildingCoords(4.60220, -74.06410),
  'Plazoleta Central': BuildingCoords(4.60200, -74.06470),
  'Plazoleta del Edificio ML': BuildingCoords(4.60270, -74.06540),
  'Senda Peatonal': BuildingCoords(4.60240, -74.06500),
};
