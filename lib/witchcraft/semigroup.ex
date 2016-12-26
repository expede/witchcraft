import TypeClass

defclass Witchcraft.Semigroup do
  use Operator

  where do
    @operator :<|>
    def concat(a, b)
  end

  properties do
    def associative(data) do
      a = generate(data)
      b = generate(data)
      c = generate(data)

      left  = a |> Semigroup.concat(b) |> Semigroup.concat(c)
      right = Semigroup.concat(a, Semigroup.concat(b, c))
      left == right
    end
  end
end

definst Witchcraft.Semigroup, for: List do
  def concat(a, b), do: a ++ b
end
