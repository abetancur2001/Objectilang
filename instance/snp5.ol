object Persona[T](val nombre: String, val inicial: Char, val edad: Integer, val dato: T)
object Caja[+A](val items: List[A], val activo: Boolean)

method main {
  val c: Char = 'x'
  val p: Persona[Integer] = new Persona[Integer]("Ana", 'A', 20, 5)
  println(c)
}