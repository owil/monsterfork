//  Package imports.
import classNames from 'classnames';
import PropTypes from 'prop-types';
import React from 'react';
import { defineMessages, FormattedMessage, injectIntl } from 'react-intl';
import { length } from 'stringz';
import ImmutablePureComponent from 'react-immutable-pure-component';

//  Components.
import Button from 'flavours/glitch/components/button';
import Icon from 'flavours/glitch/components/icon';

//  Utils.
import { maxChars } from 'flavours/glitch/util/initial_state';

//  Messages.
const messages = defineMessages({
  publish: {
    defaultMessage: 'Toot',
    id: 'compose_form.publish',
  },
  publishLoud: {
    defaultMessage: '{publish}!',
    id: 'compose_form.publish_loud',
  },
  clear: {
    defaultMessage: 'Double-click to clear',
    id: 'compose_form.clear',
  },
});

export default @injectIntl
class Publisher extends ImmutablePureComponent {

  static propTypes = {
    countText: PropTypes.string,
    disabled: PropTypes.bool,
    intl: PropTypes.object.isRequired,
    onSecondarySubmit: PropTypes.func,
    onSubmit: PropTypes.func,
    onClearAll: PropTypes.func,
    privacy: PropTypes.oneOf(['direct', 'private', 'unlisted', 'public']),
    privacyWarning: PropTypes.bool,
    sideArm: PropTypes.oneOf(['none', 'direct', 'private', 'unlisted', 'public']),
    sideArmWarning: PropTypes.bool,
  };

  handleSubmit = () => {
    this.props.onSubmit();
  };

  render () {
    const { countText, disabled, intl, onClearAll, onSecondarySubmit, privacy, privacyWarning, sideArm, sideArmWarning } = this.props;

    const diff = maxChars - length(countText || '');
    const computedClass = classNames('composer--publisher', {
      disabled: disabled || diff < 0,
      over: diff < 0,
    });

    return (
      <div className={computedClass}>
        <Button
          className='clear'
          onClick={onClearAll}
          style={{ padding: null }}
          title={intl.formatMessage(messages.clear)}
          text={
            <span>
              <Icon id='trash-o' />
            </span>
          }
        />
        {sideArm && sideArm !== 'none' ? (
          <Button
            className={classNames('side_arm', {privacy_warning: sideArmWarning})}
            disabled={disabled || diff < 0}
            onClick={onSecondarySubmit}
            style={{ padding: null }}
            text={
              <span>
                <Icon
                  id={{
                    public: 'globe',
                    unlisted: 'unlock',
                    private: 'lock',
                    direct: 'envelope',
                  }[sideArm]}
                />
              </span>
            }
            title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage({ id: `privacy.${sideArm}.short` })}`}
          />
        ) : null}
        <Button
          className={classNames('primary', {privacy_warning: privacyWarning})}
          text={function () {
            switch (true) {
            case !!sideArm && sideArm !== 'none':
            case privacy === 'direct':
            case privacy === 'private':
              return (
                <span>
                  <Icon
                    id={{
                      direct: 'envelope',
                      private: 'lock',
                      public: 'globe',
                      unlisted: 'unlock',
                    }[privacy]}
                  />
                  {' '}
                  <FormattedMessage {...messages.publish} />
                </span>
              );
            case privacy === 'public':
              return (
                <span>
                  <FormattedMessage
                    {...messages.publishLoud}
                    values={{ publish: <FormattedMessage {...messages.publish} /> }}
                  />
                </span>
              );
            default:
              return <span><FormattedMessage {...messages.publish} /></span>;
            }
          }()}
          title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage({ id: `privacy.${privacy}.short` })}`}
          onClick={this.handleSubmit}
          disabled={disabled || diff < 0}
        />
      </div>
    );
  };
}
