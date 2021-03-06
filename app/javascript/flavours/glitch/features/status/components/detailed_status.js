import React from 'react';
import PropTypes from 'prop-types';
import ImmutablePropTypes from 'react-immutable-proptypes';
import Avatar from 'flavours/glitch/components/avatar';
import DisplayName from 'flavours/glitch/components/display_name';
import StatusContent from 'flavours/glitch/components/status_content';
import MediaGallery from 'flavours/glitch/components/media_gallery';
import AttachmentList from 'flavours/glitch/components/attachment_list';
import { Link } from 'react-router-dom';
import { FormattedDate } from 'react-intl';
import Card from './card';
import ImmutablePureComponent from 'react-immutable-pure-component';
import Video from 'flavours/glitch/features/video';
import Audio from 'flavours/glitch/features/audio';
import VisibilityIcon from 'flavours/glitch/components/status_visibility_icon';
import scheduleIdleTask from 'flavours/glitch/util/schedule_idle_task';
import classNames from 'classnames';
import PollContainer from 'flavours/glitch/containers/poll_container';
import Icon from 'flavours/glitch/components/icon';
import { me } from 'flavours/glitch/util/initial_state';
import PictureInPicturePlaceholder from 'flavours/glitch/components/picture_in_picture_placeholder';

export default class DetailedStatus extends ImmutablePureComponent {

  static contextTypes = {
    router: PropTypes.object,
  };

  static propTypes = {
    status: ImmutablePropTypes.map,
    settings: ImmutablePropTypes.map.isRequired,
    onOpenMedia: PropTypes.func.isRequired,
    onOpenVideo: PropTypes.func.isRequired,
    onToggleHidden: PropTypes.func,
    expanded: PropTypes.bool,
    measureHeight: PropTypes.bool,
    onHeightChange: PropTypes.func,
    domain: PropTypes.string.isRequired,
    compact: PropTypes.bool,
    showMedia: PropTypes.bool,
    usingPiP: PropTypes.bool,
    onToggleMediaVisibility: PropTypes.func,
  };

  state = {
    height: null,
  };

  handleAccountClick = (e) => {
    if (e.button === 0 && !(e.ctrlKey || e.altKey || e.metaKey) && this.context.router) {
      e.preventDefault();
      let state = {...this.context.router.history.location.state};
      state.mastodonBackSteps = (state.mastodonBackSteps || 0) + 1;
      this.context.router.history.push(`/accounts/${this.props.status.getIn(['account', 'id'])}`, state);
    }

    e.stopPropagation();
  }

  parseClick = (e, destination) => {
    if (e.button === 0 && !(e.ctrlKey || e.altKey || e.metaKey) && this.context.router) {
      e.preventDefault();
      let state = {...this.context.router.history.location.state};
      state.mastodonBackSteps = (state.mastodonBackSteps || 0) + 1;
      this.context.router.history.push(destination, state);
    }

    e.stopPropagation();
  }

  handleOpenVideo = (media, options) => {
    this.props.onOpenVideo(media, options);
  }

  _measureHeight (heightJustChanged) {
    if (this.props.measureHeight && this.node) {
      scheduleIdleTask(() => this.node && this.setState({ height: Math.ceil(this.node.scrollHeight) + 1 }));

      if (this.props.onHeightChange && heightJustChanged) {
        this.props.onHeightChange();
      }
    }
  }

  setRef = c => {
    this.node = c;
    this._measureHeight();
  }

  componentDidUpdate (prevProps, prevState) {
    this._measureHeight(prevState.height !== this.state.height);
  }

  handleChildUpdate = () => {
    this._measureHeight();
  }

  handleModalLink = e => {
    e.preventDefault();

    let href;

    if (e.target.nodeName !== 'A') {
      href = e.target.parentNode.href;
    } else {
      href = e.target.href;
    }

    window.open(href, 'mastodon-intent', 'width=445,height=600,resizable=no,menubar=no,status=no,scrollbars=yes');
  }

  render () {
    const status = (this.props.status && this.props.status.get('reblog')) ? this.props.status.get('reblog') : this.props.status;
    const { expanded, onToggleHidden, settings, usingPiP } = this.props;
    const outerStyle = { boxSizing: 'border-box' };
    const { compact } = this.props;

    if (!status) {
      return null;
    }

    let media           = null;
    let mediaIcon       = null;
    let applicationLink = '';
    let reblogLink = '';
    let reblogIcon = 'retweet';
    let favouriteLink = '';

    if (this.props.measureHeight) {
      outerStyle.height = `${this.state.height}px`;
    }

    if (status.get('poll')) {
      media = <PollContainer pollId={status.get('poll')} />;
      mediaIcon = 'tasks';
    } else if (usingPiP) {
      media = <PictureInPicturePlaceholder />;
      mediaIcon = 'video-camera';
    } else if (status.get('media_attachments').size > 0) {
      if (status.get('media_attachments').some(item => item.get('type') === 'unknown')) {
        media = <AttachmentList media={status.get('media_attachments')} />;
      } else if (status.getIn(['media_attachments', 0, 'type']) === 'audio') {
        const attachment = status.getIn(['media_attachments', 0]);

        media = (
          <Audio
            src={attachment.get('url')}
            alt={attachment.get('description')}
            duration={attachment.getIn(['meta', 'original', 'duration'], 0)}
            poster={attachment.get('preview_url') || status.getIn(['account', 'avatar_static'])}
            backgroundColor={attachment.getIn(['meta', 'colors', 'background'])}
            foregroundColor={attachment.getIn(['meta', 'colors', 'foreground'])}
            accentColor={attachment.getIn(['meta', 'colors', 'accent'])}
            height={150}
          />
        );
        mediaIcon = 'music';
      } else if (status.getIn(['media_attachments', 0, 'type']) === 'video') {
        const attachment = status.getIn(['media_attachments', 0]);
        media = (
          <Video
            preview={attachment.get('preview_url')}
            blurhash={attachment.get('blurhash')}
            src={attachment.get('url')}
            alt={attachment.get('description')}
            inline
            sensitive={status.get('sensitive')}
            letterbox={settings.getIn(['media', 'letterbox'])}
            fullwidth={settings.getIn(['media', 'fullwidth'])}
            preventPlayback={!expanded}
            onOpenVideo={this.handleOpenVideo}
            autoplay
            visible={this.props.showMedia}
            onToggleVisibility={this.props.onToggleMediaVisibility}
          />
        );
        mediaIcon = 'video-camera';
      } else {
        media = (
          <MediaGallery
            standalone
            sensitive={status.get('sensitive')}
            media={status.get('media_attachments')}
            letterbox={settings.getIn(['media', 'letterbox'])}
            fullwidth={settings.getIn(['media', 'fullwidth'])}
            hidden={!expanded}
            onOpenMedia={this.props.onOpenMedia}
            visible={this.props.showMedia}
            onToggleVisibility={this.props.onToggleMediaVisibility}
          />
        );
        mediaIcon = 'picture-o';
      }
    } else if (status.get('card')) {
      media = <Card sensitive={status.get('sensitive')} onOpenMedia={this.props.onOpenMedia} card={status.get('card')} />;
      mediaIcon = 'link';
    }

    if (status.get('application')) {
      applicationLink = <React.Fragment> · <a className='detailed-status__application' href={status.getIn(['application', 'website'])} target='_blank' rel='noopener noreferrer'>{status.getIn(['application', 'name'])}</a></React.Fragment>;
    }

    const visibilityLink = <React.Fragment><VisibilityIcon visibility={status.get('visibility')} /> · </React.Fragment>;

    if (status.get('visibility') === 'direct') {
      reblogIcon = 'envelope';
    } else if (status.get('visibility') === 'private') {
      reblogIcon = 'lock';
    }

    if (status.getIn(['account', 'id']) !== me || !['unlisted', 'public'].includes(status.get('visibility'))) {
      reblogLink = null;
    } else if (this.context.router) {
      reblogLink = (
        <React.Fragment>
          <React.Fragment> · </React.Fragment>
          <Link to={`/statuses/${status.get('id')}/reblogs`} className='detailed-status__link'>
            <Icon id={reblogIcon} />
          </Link>
        </React.Fragment>
      );
    } else {
      reblogLink = (
        <React.Fragment>
          <React.Fragment> · </React.Fragment>
          <a href={`/interact/${status.get('id')}?type=reblog`} className='detailed-status__link' onClick={this.handleModalLink}>
            <Icon id={reblogIcon} />
          </a>
        </React.Fragment>
      );
    }

    if (status.getIn(['account', 'id']) !== me) {
      favouriteLink = null;
    } else if (this.context.router) {
      favouriteLink = (
        <React.Fragment>
          <React.Fragment> · </React.Fragment>
          <Link to={`/statuses/${status.get('id')}/favourites`} className='detailed-status__link'>
            <Icon id='star' />
          </Link>
        </React.Fragment>
      );
    } else {
      favouriteLink = (
        <React.Fragment>
          <React.Fragment> · </React.Fragment>
          <a href={`/interact/${status.get('id')}?type=favourite`} className='detailed-status__link' onClick={this.handleModalLink}>
            <Icon id='star' />
          </a>
        </React.Fragment>
      );
    }

    const selectorAttribs = {
      'data-status-by': `@${status.getIn(['account', 'acct'])}`,
      'data-nest-level': status.get('nest_level'),
      'data-nest-deep': status.get('nest_level') >= 15,
      'data-local-only': !!status.get('local_only'),
    };

    return (
      <div style={outerStyle}>
        <div ref={this.setRef} className={classNames('detailed-status', `detailed-status-${status.get('visibility')}`, { compact, unpublished: status.get('published') === false })} {...selectorAttribs}>
          <a href={status.getIn(['account', 'url'])} onClick={this.handleAccountClick} className='detailed-status__display-name'>
            <div className='detailed-status__display-avatar'><Avatar account={status.get('account')} size={48} /></div>
            <DisplayName account={status.get('account')} localDomain={this.props.domain} />
          </a>

          <StatusContent
            status={status}
            media={media}
            mediaIcon={mediaIcon}
            expanded={expanded}
            collapsed={false}
            onExpandedToggle={onToggleHidden}
            parseClick={this.parseClick}
            onUpdate={this.handleChildUpdate}
            tagLinks={settings.get('tag_misleading_links')}
            rewriteMentions={settings.get('rewrite_mentions')}
            article
            disabled
          />

          <div className='detailed-status__meta'>
            {visibilityLink}
            <a className='detailed-status__datetime' href={status.get('url')} target='_blank' rel='noopener noreferrer'>
              <FormattedDate value={new Date(status.get('created_at'))} hour12={false} year='numeric' month='short' day='2-digit' hour='2-digit' minute='2-digit' />
            </a>{applicationLink}{reblogLink}{favouriteLink}
          </div>
        </div>
      </div>
    );
  }

}
