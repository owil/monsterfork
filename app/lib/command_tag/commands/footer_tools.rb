# frozen_string_literal: true
module CommandTag::Commands::FooterTools
  def handle_999_footertools_startup
    @status.footer = var('persist:footer:default')[0]
  end

  def handle_footer_before_save(args)
    return if args.blank?

    name = normalize(args.shift)
    return (@status.footer = nil) if read_falsy_from(name)

    var_name = "persist:footer:#{name}"
    return @status.footer = var(var_name)[0] if args.blank?

    if read_falsy_from(normalize(args[0]))
      @status.footer = nil if ['default', var(var_name)[0]].include?(name)
      @vars.delete(var_name)
      return
    end

    if name == 'default'
      name = normalize(args.shift)
      var_name = "persist:footer:#{name}"
      @vars[var_name] = [args.join(' ').strip] if args.present?
      @vars['persist:footer:default'] = var(var_name)
    elsif %w(default DEFAULT).include?(args[0])
      @vars['persist:footer:default'] = var(var_name)
    else
      @vars[var_name] = [args.join(' ').strip]
    end

    @status.footer = var(var_name)[0]
  end

  # Monsterfork v1 familiarity.
  def handle_i_before_save(args)
    return if args.blank?

    handle_footer_before_save(args[1..-1]) if %w(am are).include?(normalize(args[0]))
  end

  alias handle_we_before_save           handle_i_before_save
  alias handle_signature_before_save    handle_footer_before_save
  alias handle_signed_before_save       handle_footer_before_save
  alias handle_sign_before_save         handle_footer_before_save
  alias handle_sig_before_save          handle_footer_before_save
  alias handle_am_before_save           handle_footer_before_save
  alias handle_are_before_save          handle_footer_before_save
end
