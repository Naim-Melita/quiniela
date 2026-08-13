/// Hora de Argentina, sin importar en que huso este el telefono.
///
/// Los sorteos son a horario argentino. Usar `DateTime.now()` local hace que la
/// agenda del dia salga corrida en cualquier telefono que no este en UTC-3, y
/// peor: [QuinielaRepository] decide con esa hora que turnos ya se publicaron,
/// asi que pide sorteos que todavia no existen o se saltea los que si.
///
/// Se comprobo en el emulador, que corre en GMT: con las 18:05 de Argentina la
/// app mostraba la Vespertina como finalizada y la Nocturna en vivo.
///
/// Argentina esta en UTC-3 fijo y no aplica horario de verano, asi que alcanza
/// con el desplazamiento constante y no hace falta la base de datos de husos.
library;

const desplazamientoArgentina = Duration(hours: -3);

/// Ahora en hora argentina, como DateTime local para que se pueda comparar y
/// formatear igual que el resto de las fechas de la app.
DateTime ahoraEnArgentina() {
  final enArgentina = DateTime.now().toUtc().add(desplazamientoArgentina);
  return DateTime(
    enArgentina.year,
    enArgentina.month,
    enArgentina.day,
    enArgentina.hour,
    enArgentina.minute,
    enArgentina.second,
  );
}
