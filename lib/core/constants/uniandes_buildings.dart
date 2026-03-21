/// Common buildings and locations at Universidad de los Andes campus.
/// Used as a pick-list when posting items so buyers know the meeting point.
const List<String> uniAndesBuildings = [
  'Mario Laserna',
  'Santo Domingo',
  'Centro del Japón',
  'Centro Cívico (RGD)',
  'Cafetería Central',
  'Edificio Lleras',
  'Centro Deportivo',
];

/// GPS coordinates (latitude, longitude) for each building.
class BuildingCoords {
  final double lat;
  final double lng;
  const BuildingCoords(this.lat, this.lng);
}

const Map<String, BuildingCoords> buildingCoordinates = {
  'Mario Laserna':       BuildingCoords(4.60270, -74.06590),
  'Santo Domingo':       BuildingCoords(4.60160, -74.06580),
  'Centro del Japón':    BuildingCoords(4.60330, -74.06570),
  'Centro Cívico (RGD)': BuildingCoords(4.60210, -74.06600),
  'Cafetería Central':   BuildingCoords(4.60250, -74.06630),
  'Edificio Lleras':     BuildingCoords(4.60280, -74.06650),
  'Centro Deportivo':    BuildingCoords(4.600093, -74.062675), 
};
