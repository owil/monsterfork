import React from 'react';
import ImmutablePropTypes from 'react-immutable-proptypes';
import PropTypes from 'prop-types';
import { isRtl } from 'flavours/glitch/util/rtl';
import { FormattedMessage } from 'react-intl';
import Permalink from './permalink';
import RelativeTimestamp from 'flavours/glitch/components/relative_timestamp';
import classnames from 'classnames';
import Icon from 'flavours/glitch/components/icon';
import { autoPlayGif } from 'flavours/glitch/util/initial_state';
import { decode as decodeIDNA } from 'flavours/glitch/util/idna';

const textMatchesTarget = (text, origin, host) => {
  return (text === origin || text === host
          || text.startsWith(origin + '/') || text.startsWith(host + '/')
          || 'www.' + text === host || ('www.' + text).startsWith(host + '/'));
};

const isLinkMisleading = (link) => {
  let linkTextParts = [];

  // Reconstruct visible text, as we do not have much control over how links
  // from remote software look, and we can't rely on `innerText` because the
  // `invisible` class does not set `display` to `none`.

  const walk = (node) => {
    switch (node.nodeType) {
    case Node.TEXT_NODE:
      linkTextParts.push(node.textContent);
      break;
    case Node.ELEMENT_NODE:
      if (node.classList.contains('invisible')) return;
      const children = node.childNodes;
      for (let i = 0; i < children.length; i++) {
        walk(children[i]);
      }
      break;
    }
  };

  walk(link);

  const linkText = linkTextParts.join('');
  const targetURL = new URL(link.href);

  if (targetURL.protocol === 'magnet:') {
    return !linkText.startsWith('magnet:');
  }

  if (targetURL.protocol === 'xmpp:') {
    return !(linkText === targetURL.href || 'xmpp:' + linkText === targetURL.href);
  }

  // The following may not work with international domain names
  if (textMatchesTarget(linkText, targetURL.origin, targetURL.host) || textMatchesTarget(linkText.toLowerCase(), targetURL.origin, targetURL.host)) {
    return false;
  }

  // The link hasn't been recognized, maybe it features an international domain name
  const hostname = decodeIDNA(targetURL.hostname).normalize('NFKC');
  const host = targetURL.host.replace(targetURL.hostname, hostname);
  const origin = targetURL.origin.replace(targetURL.host, host);
  const text = linkText.normalize('NFKC');
  return !(textMatchesTarget(text, origin, host) || textMatchesTarget(text.toLowerCase(), origin, host));
};

export default class StatusContent extends React.PureComponent {

  static propTypes = {
    status: ImmutablePropTypes.map.isRequired,
    expanded: PropTypes.bool,
    collapsed: PropTypes.bool,
    onExpandedToggle: PropTypes.func,
    media: PropTypes.element,
    mediaIcon: PropTypes.string,
    parseClick: PropTypes.func,
    disabled: PropTypes.bool,
    onUpdate: PropTypes.func,
    tagLinks: PropTypes.bool,
    rewriteMentions: PropTypes.string,
    article: PropTypes.bool,
  };

  static defaultProps = {
    tagLinks: true,
    rewriteMentions: 'no',
    article: false,
  };

  state = {
    hidden: true,
  };

  _updateStatusLinks () {
    const node = this.contentsNode;
    const { tagLinks, rewriteMentions } = this.props;

    if (!node) {
      return;
    }

    const links = node.querySelectorAll('a');

    for (var i = 0; i < links.length; ++i) {
      let link = links[i];
      if (link.classList.contains('status-link')) {
        continue;
      }
      link.classList.add('status-link');

      let mention = this.props.status.get('mentions').find(item => link.href === item.get('url'));

      if (mention) {
        link.addEventListener('click', this.onMentionClick.bind(this, mention), false);
        link.setAttribute('title', mention.get('acct'));
        if (rewriteMentions !== 'no') {
          while (link.firstChild) link.removeChild(link.firstChild);
          link.appendChild(document.createTextNode('@'));
          const acctSpan = document.createElement('span');
          acctSpan.textContent = rewriteMentions === 'acct' ? mention.get('acct') : mention.get('username');
          link.appendChild(acctSpan);
        }
      } else if (link.textContent[0] === '#' || (link.previousSibling && link.previousSibling.textContent && link.previousSibling.textContent[link.previousSibling.textContent.length - 1] === '#')) {
        link.addEventListener('click', this.onHashtagClick.bind(this, link.text), false);
      } else {
        link.addEventListener('click', this.onLinkClick.bind(this), false);
        link.setAttribute('title', link.href);
        link.classList.add('unhandled-link');

        try {
          if (tagLinks && isLinkMisleading(link)) {
            // Add a tag besides the link to display its origin

            const url = new URL(link.href);
            const tag = document.createElement('span');
            tag.classList.add('link-origin-tag');
            switch (url.protocol) {
            case 'xmpp:':
              tag.textContent = `[${url.href}]`;
              break;
            case 'magnet:':
              tag.textContent = '(magnet)';
              break;
            default:
              tag.textContent = `[${url.host}]`;
            }
            link.insertAdjacentText('beforeend', ' ');
            link.insertAdjacentElement('beforeend', tag);
          }
        } catch (e) {
          // The URL is invalid, remove the href just to be safe
          if (tagLinks && e instanceof TypeError) link.removeAttribute('href');
        }
      }

      link.setAttribute('target', '_blank');
      link.setAttribute('rel', 'noopener noreferrer');
    }
  }

  _updateStatusEmojis () {
    const node = this.node;

    if (!node || autoPlayGif) {
      return;
    }

    const emojis = node.querySelectorAll('.custom-emoji');

    for (var i = 0; i < emojis.length; i++) {
      let emoji = emojis[i];
      if (emoji.classList.contains('status-emoji')) {
        continue;
      }
      emoji.classList.add('status-emoji');

      emoji.addEventListener('mouseenter', this.handleEmojiMouseEnter, false);
      emoji.addEventListener('mouseleave', this.handleEmojiMouseLeave, false);
    }
  }

  componentDidMount () {
    this._updateStatusLinks();
    this._updateStatusEmojis();
  }

  componentDidUpdate () {
    this._updateStatusLinks();
    this._updateStatusEmojis();
    if (this.props.onUpdate) this.props.onUpdate();
  }

  onLinkClick = (e) => {
    if (this.props.collapsed) {
      if (this.props.parseClick) this.props.parseClick(e);
    }
  }

  onMentionClick = (mention, e) => {
    if (this.props.parseClick) {
      this.props.parseClick(e, `/accounts/${mention.get('id')}`);
    }
  }

  onHashtagClick = (hashtag, e) => {
    hashtag = hashtag.replace(/^#/, '');

    if (this.props.parseClick) {
      this.props.parseClick(e, `/timelines/tag/${hashtag}`);
    }
  }

  handleEmojiMouseEnter = ({ target }) => {
    target.src = target.getAttribute('data-original');
  }

  handleEmojiMouseLeave = ({ target }) => {
    target.src = target.getAttribute('data-static');
  }

  handleMouseDown = (e) => {
    this.startXY = [e.clientX, e.clientY];
  }

  handleMouseUp = (e) => {
    const { parseClick, disabled } = this.props;

    if (disabled || !this.startXY) {
      return;
    }

    const [ startX, startY ] = this.startXY;
    const [ deltaX, deltaY ] = [Math.abs(e.clientX - startX), Math.abs(e.clientY - startY)];

    let element = e.target;
    while (element) {
      if (['button', 'video', 'a', 'label', 'canvas', 'details', 'summary'].includes(element.localName)) {
        return;
      }
      element = element.parentNode;
    }

    if (deltaX + deltaY < 5 && e.button === 0 && parseClick) {
      parseClick(e);
    }

    this.startXY = null;
  }

  handleSpoilerClick = (e) => {
    e.preventDefault();

    if (this.props.onExpandedToggle) {
      this.props.onExpandedToggle();
    } else {
      this.setState({ hidden: !this.state.hidden });
    }
  }

  setRef = (c) => {
    this.node = c;
  }

  setContentsRef = (c) => {
    this.contentsNode = c;
  }

  render () {
    const {
      status,
      media,
      mediaIcon,
      parseClick,
      disabled,
      tagLinks,
      rewriteMentions,
      article,
    } = this.props;

    const hidden = this.props.onExpandedToggle ? !this.props.expanded : this.state.hidden;

    const edited = (status.get('edited') === 0) ? null : (
      <div className='status__notice status__edit-notice'>
        <Icon id='pencil-square-o' />
        <FormattedMessage
          id='status.edited'
          defaultMessage='{count, plural, one {# edit} other {# edits}} · last update: {updated_at}'
          key={`edit-${status.get('id')}`}
          values={{
            count: status.get('edited'),
            updated_at: <RelativeTimestamp timestamp={status.get('updated_at')} />,
          }}
        />
      </div>
    );

    const unpublished = (status.get('published') === false) && (
      <div className='status__notice status__unpublished-notice'>
        <Icon id='chain-broken' />
        <FormattedMessage
          id='status.unpublished'
          defaultMessage='Unpublished'
          key={`unpublished-${status.get('id')}`}
        />
      </div>
    );

    const local_only = (status.get('local_only') === true) && (
      <div className='status__notice status__localonly-notice'>
        <Icon id='home' />
        <FormattedMessage
          id='advanced_options.local-only.short'
          defaultMessage='Local-only'
          key={`localonly-${status.get('id')}`}
        />
      </div>
    );

    const quiet = (status.get('notify') === false) && (
      <div className='status__notice status__quiet-notice'>
        <Icon id='bell-slash' />
        <FormattedMessage
          id='status.quiet'
          defaultMessage='Quiet local publish'
          key={`quiet-${status.get('id')}`}
        />
      </div>
    );

    const article_content = status.get('article') && (
      <div className='status__notice status__article-notice'>
        <Icon id='file-text-o' />
        <Permalink
          href={status.get('url')}
          to={`/statuses/${status.get('id')}`}
        >
          <FormattedMessage
            id='status.article'
            defaultMessage='Article'
            key={`article-${status.get('id')}`}
          />
        </Permalink>
      </div>
    );

    const publish_at = status.get('publish_at') && (
      <div className='status__notice status__publish-notice'>
        <Icon id='bullhorn' />
        <FormattedMessage
          id='status.publish_at'
          defaultMessage='Auto-publish: {publish_at}'
          key={`publish-${status.get('id')}`}
          values={{
            publish_at: <RelativeTimestamp timestamp={status.get('publish_at')} futureDate />,
          }}
        />
      </div>
    );

    const expires_at = !unpublished && status.get('expires_at') && (
      <div className='status__notice status__expires-notice'>
        <Icon id='clock-o' />
        <FormattedMessage
          id='status.expires_at'
          defaultMessage='Self-destruct: {expires_at}'
          key={`expires-${status.get('id')}`}
          values={{
            expires_at: <RelativeTimestamp timestamp={status.get('expires_at')} futureDate />,
          }}
        />
      </div>
    );

    const status_notice_wrapper = (
      <div className='status__notice-wrapper'>
        {unpublished}
        {publish_at}
        {expires_at}
        {quiet}
        {edited}
        {local_only}
        {article_content}
      </div>
    );

    const permissions_present = status.get('domain_permissions') && status.get('domain_permissions').size > 0;

    const status_permission_items = permissions_present && status.get('domain_permissions').map((permission) => (
      <li className='permission-status'>
        <Icon id='eye-slash' />
        <FormattedMessage
          id='status.permissions.visibility.status'
          defaultMessage='{visibility} 🡲 {domain}'
          key={`permissions-visibility-${status.get('id')}`}
          values={{
            domain: <span>{permission.get('domain')}</span>,
            visibility: <span>{permission.get('visibility')}</span>,
          }}
        />
      </li>
    ));

    const permissions = status_permission_items && (
      <details className='status__permissions' onMouseDown={this.handleMouseDown} onMouseUp={this.handleMouseUp}>
        <summary>
          <Icon id='unlock-alt' />
          <FormattedMessage
            id='status.permissions.title'
            defaultMessage='Show extended permissions...'
            key={`permissions-${status.get('id')}`}
          />
        </summary>
        <ul>
          {status_permission_items}
        </ul>
      </details>
    );

    const tag_items = (status.get('tags') && status.get('tags').size > 0) && status.get('tags').map(hashtag =>
      (
        <li>
          <Icon id='tag' />
          <Permalink
            href={hashtag.get('url')}
            to={`/timelines/tag/${hashtag.get('name')}`}
          >
            <span>{hashtag.get('name')}</span>
          </Permalink>
        </li>
      ));

    const tags = tag_items && (
      <details className='status__tags' onMouseDown={this.handleMouseDown} onMouseUp={this.handleMouseUp}>
        <summary>
          <Icon id='tag' />
          <FormattedMessage
            id='status.tags'
            defaultMessage='Show all tags...'
            key={`tags-${status.get('id')}`}
          />
        </summary>
        <ul>
          {tag_items}
        </ul>
      </details>
    );

    const footers = (
      <div className='status__footers'>
        {permissions}
        {tags}
      </div>
    );

    const reblog_spoiler_html = status.get('reblogSpoilerPresent') && { __html: status.get('reblogSpoilerHtml') };
    const reblog_spoiler = reblog_spoiler_html && (
      <div className='reblog-spoiler spoiler'>
        <Icon id='retweet' />
        <span dangerouslySetInnerHTML={reblog_spoiler_html} />
      </div>
    );

    const spoiler_html = status.get('spoiler_text').length > 0 && { __html: status.get('spoilerHtml') };
    const spoiler = spoiler_html && (
      <div className='spoiler'>
        <Icon id='info-circle' />
        <span dangerouslySetInnerHTML={spoiler_html} />
      </div>
    );

    const spoiler_present = status.get('spoiler_text').length > 0 || status.get('reblogSpoilerPresent');
    const content = { __html: article ? status.get('articleHtml') : status.get('contentHtml') };
    const directionStyle = { direction: 'ltr' };
    const classNames = classnames('status__content', {
      'status__content--with-action': parseClick && !disabled,
      'status__content--with-spoiler': spoiler_present,
    });

    if (isRtl(status.get('search_index'))) {
      directionStyle.direction = 'rtl';
    }

    if (spoiler_present) {
      let mentionsPlaceholder = '';

      const mentionLinks = status.get('mentions').map(item => (
        <Permalink
          to={`/accounts/${item.get('id')}`}
          href={item.get('url')}
          key={item.get('id')}
          className='mention'
        >
          @<span>{item.get('username')}</span>
        </Permalink>
      )).reduce((aggregate, item) => [...aggregate, item, ' '], []);

      const toggleText = hidden ? [
        article ? (
          <FormattedMessage
            id='status.show_article'
            defaultMessage='Show article'
            key='0'
          />
        ) : (
          <FormattedMessage
            id='status.show_more'
            defaultMessage='Show more'
            key='0'
          />
        ),
        mediaIcon ? (
          <Icon
            fixedWidth
            className='status__content__spoiler-icon'
            id={mediaIcon}
            aria-hidden='true'
            key='1'
          />
        ) : null,
      ] : [
        <FormattedMessage
          id='status.show_less'
          defaultMessage='Show less'
          key='0'
        />,
      ];

      if (hidden) {
        mentionsPlaceholder = <div>{mentionLinks}</div>;
      }

      return (
        <div className={classNames} tabIndex='0' onMouseDown={this.handleMouseDown} onMouseUp={this.handleMouseUp} ref={this.setRef}>
          {status_notice_wrapper}
          <div
            style={{ marginBottom: hidden && status.get('mentions').isEmpty() ? '0px' : null }}
          >
            {reblog_spoiler}
            {spoiler}
            <div class='spoiler-actions'>
              <button tabIndex='0' className='status__content__spoiler-link' onClick={this.handleSpoilerClick}>
                {toggleText}
              </button>
            </div>
          </div>

          {mentionsPlaceholder}

          <div className={`status__content__spoiler ${!hidden ? 'status__content__spoiler--visible' : ''}`}>
            <div
              ref={this.setContentsRef}
              key={`contents-${tagLinks}`}
              style={directionStyle}
              tabIndex={!hidden ? 0 : null}
              dangerouslySetInnerHTML={content}
              className='status__content__text'
            />
            {media}
          </div>

          {footers}

        </div>
      );
    } else if (parseClick) {
      return (
        <div
          className={classNames}
          style={directionStyle}
          onMouseDown={this.handleMouseDown}
          onMouseUp={this.handleMouseUp}
          tabIndex='0'
          ref={this.setRef}
        >
          {status_notice_wrapper}
          <div
            ref={this.setContentsRef}
            key={`contents-${tagLinks}-${rewriteMentions}`}
            dangerouslySetInnerHTML={content}
            className='status__content__text'
            tabIndex='0'
          />
          {media}
          {footers}
        </div>
      );
    } else {
      return (
        <div
          className='status__content'
          style={directionStyle}
          tabIndex='0'
          ref={this.setRef}
        >
          {status_notice_wrapper}
          <div ref={this.setContentsRef} key={`contents-${tagLinks}`} className='status__content__text' dangerouslySetInnerHTML={content} tabIndex='0' />
          {media}
          {footers}
        </div>
      );
    }
  }

}
