object Animal
object Box[+T](val item: T)

Box.get = method(valor: T): T

method main {
    val caja: Box[Animal] = new Box
}