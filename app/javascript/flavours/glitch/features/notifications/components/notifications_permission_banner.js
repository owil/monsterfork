import React from 'react';
import Icon from 'flavours/glitch/components/icon';
import Button from 'flavours/glitch/components/button';
import IconButton from 'flavours/glitch/components/icon_button';
import { requestBrowserPermission, dismissBrowserPermission } from 'flavours/glitch/actions/notifications';
import { connect } from 'react-redux';
import PropTypes from 'prop-types';
import { defineMessages, injectIntl, FormattedMessage } from 'react-intl';

const messages = defineMessages({
  close: { id: 'lightbox.close', defaultMessage: 'Close' },
});

export default @connect()
@injectIntl
class NotificationsPermissionBanner extends React.PureComponent {

  static propTypes = {
    dispatch: PropTypes.func.isRequired,
    intl: PropTypes.object.isRequired,
  };

  handleClickDisable = () => {
    window.location = '/settings/preferences/notifications';
  }

  handleClick = () => {
    this.props.dispatch(requestBrowserPermission());
  }

  handleClose = () => {
    this.props.dispatch(dismissBrowserPermission());
  }

  render () {
    const { intl } = this.props;

    return (
      <div className='notifications-permission-banner'>
        <div className='notifications-permission-banner__close'>
          <IconButton icon='times' onClick={this.handleClose} title={intl.formatMessage(messages.close)} />
        </div>

        <h2><FormattedMessage id='notifications_permission_banner.title' defaultMessage='Never miss a thing' /></h2>
        <p><FormattedMessage id='notifications_permission_banner.how_to_control' defaultMessage="To receive notifications when Mastodon isn't open, enable desktop notifications. You can control precisely which types of interactions generate desktop notifications through the {icon} button above once they're enabled." values={{ icon: <Icon id='sliders' /> }} /></p>
        <Button onClick={this.handleClick}><FormattedMessage id='notifications_permission_banner.enable' defaultMessage='Request' /></Button>
        <Button onClick={this.handleClickDisable}><FormattedMessage id='notifications_permission_banner.disable' defaultMessage='Disable' /></Button>
      </div>
    );
  }

}
