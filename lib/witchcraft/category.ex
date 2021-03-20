import TypeClass

defclass Witchcraft.Category do
  @moduledoc """
  A category is some collection of objects and relationships (morphisms) between them.

  This idea is captured by the notion of an identity function for objects,
  and the ability to compose relationships between objects. In most cases,
  these are very straightforward, and composition and identity are the standard
  functions from the `Quark` package or similar.

  ## Type Class

  An instance of `Witchcraft.Category` must also implement `Witchcraft.Semigroupoid`,
  and define `Witchcraft.Category.identity/1`.

      Semigroupoid  [compose/2, apply/2]
          ↓
       Category     [identity/1]
  """

  alias __MODULE__
  alias Witchcraft.Semigroupoid

  extend Witchcraft.Semigroupoid

  @type t :: any()

  defmacro __using__(opts \\ []) do
    module_imports = [except: Keyword.get(opts, :except, [])]

    quote do
      use Witchcraft.Semigroupoid, unquote(opts)
      import unquote(__MODULE__), unquote(module_imports)
    end
  end

  where do
    @doc """
    Take some value and return it again.

    ## Examples

        iex> classic_id = identity(fn -> nil end)
        ...> classic_id.(42)
        42

    """
    @spec identity(Category.t()) :: Category.t()
    def identity(category)
  end

  defalias id(category), as: :identity

  properties do
    def left_identity(data) do
      a = generate(data)
      ident = Semigroupoid.compose(Category.identity(a), a)

      equal?(a, ident)
    end

    def right_identity(data) do
      a = generate(data)
      ident = Semigroupoid.compose(a, Category.identity(a))

      equal?(a, ident)
    end
  end
end

definst Witchcraft.Category, for: Function do
  def identity(_), do: &Quark.id/1
end
