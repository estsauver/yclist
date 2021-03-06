# Exports static files for deployment

class StaticExporter

  HTML_OUTPUT_FILE = Rails.root.join('public/exported.html')

  def initialize
    raise "Use production environment" unless Rails.env.production?
  end

  def export!
    precompilation_output = precompile_assets!.strip
    `rm -f #{HTML_OUTPUT_FILE} #{HTML_OUTPUT_FILE}.gz`
    puts precompilation_output
    ensure_favicon_spritesheet_integrity
    html = get_html_output
    ensure_asset_integrity(precompilation_output, html)
    export_html!(html)
  end

  def get_html
    app = ActionDispatch::Integration::Session.new(Yclist::Application)
    app.get '/'
    app.body
  end

  private

  def precompile_assets!
    run_cmd "rake assets:clean"
    run_cmd "rake assets:precompile 2>&1"
  end

  def export_html!(html)
    open(HTML_OUTPUT_FILE, 'w') {|f| f.write html }
    `gzip -c -9 #{HTML_OUTPUT_FILE} > #{HTML_OUTPUT_FILE}.gz`
    puts "exported.html:     #{`du -hs #{HTML_OUTPUT_FILE}`}"
    puts "exported.html.gz:  #{`du -hs #{HTML_OUTPUT_FILE}.gz`}"
    puts "Generated all static files!"
  end

  # Run in a different process to avoid sporadic asset hash mismatch errors
  def get_html_output
    run_cmd "rails runner 'puts StaticExporter.new.get_html'"
  end

  def ensure_asset_integrity(precompilation, html)
    html_js_hash = html[/\/application-([a-z0-9]{64})\.js"/, 1]
    html_css_hash = html[/\/application-([a-z0-9]{64})\.css"/, 1]
    unless html_js_hash.present? && html_css_hash.present?
      raise "HTML export failed - asset hashes missing in html"
    end
    exported_js_hash = precompilation[/\/application-([a-z0-9]{64})\.js/, 1]
    exported_css_hash = precompilation[/\/application-([a-z0-9]{64})\.css/, 1]
    unless html_js_hash == exported_js_hash
      raise "JS asset hash mismatch - #{html_js_hash} #{exported_js_hash}"
    end
    unless html_css_hash == exported_css_hash
      raise "CSS asset hash mismatch - #{html_css_hash} #{exported_css_hash}"
    end
  end

  def ensure_favicon_spritesheet_integrity
    raise "Favicon spritesheet is invalid" unless FaviconSpritesheet.new.valid?
  end

  def run_cmd(cmd)
    `RAILS_ENV=production bundle exec #{cmd}`
  end
end
