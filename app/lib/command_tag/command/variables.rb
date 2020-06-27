# frozen_string_literal: true

module CommandTag::Command::Variables
  def handle_000_variables_startup
    @vars.merge!(persistent_vars_from(@account.metadata.fields)) if @account.metadata.present?
  end

  def handle_999_variables_shutdown
    @account.metadata.update!(fields: nonpersistent_vars_from(@account.metadata.fields).merge(persistent_vars_from(@vars)))
  end

  def handle_set_at_start(args)
    return if args.blank?

    args[0] = normalize(args[0])

    case args.count
    when 1
      @vars.delete(args[0])
    else
      @vars[args[0]] = args[1..-1]
    end
  end

  def do_unset_at_start(args)
    args.each do |arg|
      @vars.delete(normalize(arg))
    end
  end

  private

  def persistent_vars_from(vars)
    vars.select { |key, value| key.start_with?('persist:') && value.present? && value.is_a?(Array) }
  end

  def nonpersistent_vars_from(vars)
    vars.reject { |key, value| key.start_with?('persist:') || value.blank? }
  end
end
