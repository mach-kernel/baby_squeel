require 'baby_squeel/relation'

module BabySqueel
  class Association < Relation
    # An Active Record association reflection
    attr_reader :_reflection

    # Specifies the model that the polymorphic
    # association should join with
    attr_accessor :_polymorphic_klass

    def initialize(parent, reflection)
      @parent = parent
      @_reflection = reflection

      # In the case of a polymorphic reflection these
      # attributes will be set after calling #of
      unless @_reflection.polymorphic?
        super @_reflection.klass
      end
    end

    def of(klass)
      unless _reflection.polymorphic?
        raise PolymorphicSpecificationError.new(_reflection.name, klass)
      end

      clone.of! klass
    end

    def of!(klass)
      self._scope = klass
      self._table = klass.arel_table
      self._polymorphic_klass = klass
      self
    end

    def needs_polyamorous?
      _join == Arel::Nodes::OuterJoin || _reflection.polymorphic?
    end

    # See JoinExpression#add_to_tree.
    def add_to_tree(hash)
      polyamorous = Polyamorous::Join.new(
        _reflection.name,
        _join,
        _polymorphic_klass
      )

      hash[polyamorous] ||= {}
    end

    # See BabySqueel::Table#find_alias.
    def find_alias(association, associations = [])
      @parent.find_alias(association, [self, *associations])
    end

    # Intelligently constructs Arel nodes. There are three outcomes:
    #
    # 1. The user explicitly constructed their join using #on.
    #    See BabySqueel::Table#_arel.
    #
    #        Post.joining { author.on(author_id == author.id) }
    #
    # 2. The user aliased an implicitly joined association. ActiveRecord's
    #    join dependency gives us no way of handling this, so we have to
    #    throw an error.
    #
    #        Post.joining { author.as('some_alias') }
    #
    # 3. The user implicitly joined this association, so we pass this
    #    association up the tree until it hits the top-level BabySqueel::Table.
    #    Once it gets there, Arel join nodes will be constructed.
    #
    #        Post.joining { author }
    #
    def _arel(associations = [])
      if _on
        super
      elsif _table.is_a? Arel::Nodes::TableAlias
        raise AssociationAliasingError.new(_reflection.name, _table.right)
      elsif _reflection.polymorphic? && _polymorphic_klass.nil?
        raise PolymorphicNotSpecifiedError.new(_reflection.name)
      else
        @parent._arel([self, *associations])
      end
    end
  end
end
